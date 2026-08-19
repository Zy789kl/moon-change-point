///|
/// Online score calibration mode for deployment-specific alert rates.
pub(all) enum ProductionCalibrationMode {
  IdentityCalibration
  HistogramCalibration
  PriorWeightedCalibration
}

///|
pub fn production_calibration_mode_name(
  mode : ProductionCalibrationMode,
) -> String {
  match mode {
    IdentityCalibration => "identity"
    HistogramCalibration => "histogram"
    PriorWeightedCalibration => "prior-weighted"
  }
}

///|
/// A bin of online score-to-outcome evidence.
pub struct ProductionScoreBin {
  lower : Double
  upper : Double
  mut total : Double
  mut positives : Double
  prior_positive : Double
  prior_negative : Double
}

///|
pub fn ProductionScoreBin::new(
  lower : Double,
  upper : Double,
  prior_positive? : Double = 1.0,
  prior_negative? : Double = 1.0,
) -> ProductionScoreBin {
  {
    lower,
    upper,
    total: 0.0,
    positives: 0.0,
    prior_positive: if prior_positive < 0.0 {
      0.0
    } else {
      prior_positive
    },
    prior_negative: if prior_negative < 0.0 {
      0.0
    } else {
      prior_negative
    },
  }
}

///|
pub fn ProductionScoreBin::contains(
  self : ProductionScoreBin,
  score : Double,
) -> Bool {
  score >= self.lower && score < self.upper
}

///|
pub fn ProductionScoreBin::add(
  self : ProductionScoreBin,
  positive : Bool,
  weight : Double,
) -> Unit {
  let safe_weight = if weight <= 0.0 { 1.0 } else { weight }
  self.total += safe_weight
  if positive {
    self.positives += safe_weight
  }
}

///|
pub fn ProductionScoreBin::total(self : ProductionScoreBin) -> Double {
  self.total
}

///|
pub fn ProductionScoreBin::positives(self : ProductionScoreBin) -> Double {
  self.positives
}

///|
pub fn ProductionScoreBin::rate(self : ProductionScoreBin) -> Double {
  let numerator = self.positives + self.prior_positive
  let denominator = self.total + self.prior_positive + self.prior_negative
  if denominator <= 0.0 {
    0.0
  } else {
    numerator / denominator
  }
}

///|
pub fn ProductionScoreBin::mean_score(self : ProductionScoreBin) -> Double {
  (self.lower + self.upper) / 2.0
}

///|
pub fn ProductionScoreBin::summary(self : ProductionScoreBin) -> String {
  self.lower.to_string() +
  "-" +
  self.upper.to_string() +
  ":total=" +
  self.total.to_string() +
  ",positives=" +
  self.positives.to_string() +
  ",rate=" +
  self.rate().to_string()
}

///|
/// Bounded online calibrator with deployment-safe priors.
pub struct ProductionOnlineCalibrator {
  bins : Array[ProductionScoreBin]
  mode : ProductionCalibrationMode
  mut observations : Int
  mut positive : Int
  mut negative : Int
}

///|
pub fn ProductionOnlineCalibrator::new(
  bin_count? : Int = 16,
  mode? : ProductionCalibrationMode = PriorWeightedCalibration,
) -> ProductionOnlineCalibrator {
  let count = if bin_count < 2 { 2 } else { bin_count }
  let bins : Array[ProductionScoreBin] = []
  for i in 0..<count {
    bins.push(
      ProductionScoreBin::new(
        i.to_double() / count.to_double(),
        (i + 1).to_double() / count.to_double(),
      ),
    )
  }
  { bins, mode, observations: 0, positive: 0, negative: 0 }
}

///|
pub fn ProductionOnlineCalibrator::mode(
  self : ProductionOnlineCalibrator,
) -> ProductionCalibrationMode {
  self.mode
}

///|
pub fn ProductionOnlineCalibrator::bin_count(
  self : ProductionOnlineCalibrator,
) -> Int {
  self.bins.length()
}

///|
pub fn ProductionOnlineCalibrator::observations(
  self : ProductionOnlineCalibrator,
) -> Int {
  self.observations
}

///|
pub fn ProductionOnlineCalibrator::positive(
  self : ProductionOnlineCalibrator,
) -> Int {
  self.positive
}

///|
pub fn ProductionOnlineCalibrator::negative(
  self : ProductionOnlineCalibrator,
) -> Int {
  self.negative
}

///|
pub fn ProductionOnlineCalibrator::update(
  self : ProductionOnlineCalibrator,
  score : Double,
  changed : Bool,
  weight? : Double = 1.0,
) -> Unit {
  let safe_score = clamp_probability(score)
  let index = if safe_score >= 1.0 {
    self.bins.length() - 1
  } else {
    (safe_score * self.bins.length().to_double()).to_int()
  }
  self.bins[index].add(changed, weight)
  self.observations += 1
  if changed {
    self.positive += 1
  } else {
    self.negative += 1
  }
}

///|
pub fn ProductionOnlineCalibrator::calibrate(
  self : ProductionOnlineCalibrator,
  score : Double,
) -> Double {
  let safe_score = clamp_probability(score)
  match self.mode {
    IdentityCalibration => safe_score
    HistogramCalibration => {
      let index = if safe_score >= 1.0 {
        self.bins.length() - 1
      } else {
        (safe_score * self.bins.length().to_double()).to_int()
      }
      self.bins[index].rate()
    }
    PriorWeightedCalibration => {
      let index = if safe_score >= 1.0 {
        self.bins.length() - 1
      } else {
        (safe_score * self.bins.length().to_double()).to_int()
      }
      let rate = self.bins[index].rate()
      clamp_probability(0.5 * safe_score + 0.5 * rate)
    }
  }
}

///|
pub fn ProductionOnlineCalibrator::bins(
  self : ProductionOnlineCalibrator,
) -> Array[ProductionScoreBin] {
  let result : Array[ProductionScoreBin] = []
  for bin in self.bins {
    result.push(bin)
  }
  result
}

///|
pub fn ProductionOnlineCalibrator::reliability_error(
  self : ProductionOnlineCalibrator,
) -> Double {
  if self.observations == 0 {
    return 0.0
  }
  let mut total = 0.0
  for bin in self.bins {
    if bin.total() > 0.0 {
      total += bin.total() * absolute(bin.mean_score() - bin.rate())
    }
  }
  total / self.observations.to_double()
}

///|
pub fn ProductionOnlineCalibrator::reset(
  self : ProductionOnlineCalibrator,
) -> Unit {
  for bin in self.bins {
    bin.total = 0.0
    bin.positives = 0.0
  }
  self.observations = 0
  self.positive = 0
  self.negative = 0
}

///|
/// Converts a detector score into a calibrated detection result.
pub fn production_calibrate_result(
  calibrator : ProductionOnlineCalibrator,
  result : DetectionResult,
) -> DetectionResult {
  let calibrated = calibrator.calibrate(result.score)
  DetectionResult::new(
    calibrated >= 0.5 && result.changed,
    calibrated,
    calibrated,
    result.direction,
    result.index,
    evidence=result.evidence,
  )
}

///|
/// Adaptive threshold controller based on a recent score window and hysteresis.
pub struct ProductionThresholdController {
  scores : DoubleWindow
  target_alert_rate : Double
  minimum_threshold : Double
  maximum_threshold : Double
  hysteresis : Double
  mut threshold : Double
  mut updates : Int
}

///|
pub fn ProductionThresholdController::new(
  window_size? : Int = 256,
  target_alert_rate? : Double = 0.01,
  minimum_threshold? : Double = 0.1,
  maximum_threshold? : Double = 10.0,
  hysteresis? : Double = 0.05,
) -> ProductionThresholdController {
  let low = if minimum_threshold < 0.0 { 0.0 } else { minimum_threshold }
  let high = if maximum_threshold < low { low } else { maximum_threshold }
  {
    scores: DoubleWindow::new(if window_size < 4 { 4 } else { window_size }),
    target_alert_rate: clamp_probability(target_alert_rate),
    minimum_threshold: low,
    maximum_threshold: high,
    hysteresis: if hysteresis < 0.0 {
      0.0
    } else {
      hysteresis
    },
    threshold: high,
    updates: 0,
  }
}

///|
pub fn ProductionThresholdController::threshold(
  self : ProductionThresholdController,
) -> Double {
  self.threshold
}

///|
pub fn ProductionThresholdController::updates(
  self : ProductionThresholdController,
) -> Int {
  self.updates
}

///|
pub fn ProductionThresholdController::push(
  self : ProductionThresholdController,
  score : Double,
) -> Double {
  if !is_finite(score) {
    return self.threshold
  }
  ignore(self.scores.push(score))
  self.updates += 1
  if self.scores.length() >= 4 {
    let desired = quantile(self.scores.to_array(), 1.0 - self.target_alert_rate)
    let bounded = if desired < self.minimum_threshold {
      self.minimum_threshold
    } else if desired > self.maximum_threshold {
      self.maximum_threshold
    } else {
      desired
    }
    if absolute(bounded - self.threshold) >= self.hysteresis {
      self.threshold = bounded
    }
  }
  self.threshold
}

///|
pub fn ProductionThresholdController::reset(
  self : ProductionThresholdController,
) -> Unit {
  self.scores.clear()
  self.threshold = self.maximum_threshold
  self.updates = 0
}

///|
pub fn ProductionThresholdController::summary(
  self : ProductionThresholdController,
) -> String {
  "threshold=" +
  self.threshold.to_string() +
  ",updates=" +
  self.updates.to_string() +
  ",window=" +
  self.scores.length().to_string() +
  ",target_rate=" +
  self.target_alert_rate.to_string()
}
