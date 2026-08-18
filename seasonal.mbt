///|
/// A lightweight seasonal profile updated online with exponential forgetting.
pub struct SeasonalProfile {
  period : Int
  levels : Array[Double]
  counts : Array[Int]
  alpha : Double
  mut index : Int
}

///|
pub fn SeasonalProfile::new(
  period : Int,
  alpha? : Double = 0.1,
) -> SeasonalProfile {
  let safe_period = if period < 1 { 1 } else { period }
  {
    period: safe_period,
    levels: Array::make(safe_period, 0.0),
    counts: Array::make(safe_period, 0),
    alpha: clamp_probability(alpha),
    index: 0,
  }
}

///|
pub fn SeasonalProfile::period(self : SeasonalProfile) -> Int {
  self.period
}

///|
pub fn SeasonalProfile::update(
  self : SeasonalProfile,
  value : Double,
) -> Double {
  if !is_finite(value) {
    return 0.0
  }
  let bucket = self.index % self.period
  self.index += 1
  let baseline = self.levels[bucket]
  if self.counts[bucket] == 0 {
    self.levels[bucket] = value
  } else {
    self.levels[bucket] = baseline + self.alpha * (value - baseline)
  }
  self.counts[bucket] += 1
  value - baseline
}

///|
pub fn SeasonalProfile::baseline(self : SeasonalProfile, index : Int) -> Double {
  if self.period == 0 {
    0.0
  } else {
    self.levels[(index % self.period + self.period) % self.period]
  }
}

///|
pub fn SeasonalProfile::levels(self : SeasonalProfile) -> Array[Double] {
  let result : Array[Double] = []
  for level in self.levels {
    result.push(level)
  }
  result
}

///|
pub fn SeasonalProfile::count(self : SeasonalProfile, index : Int) -> Int {
  if self.period == 0 {
    0
  } else {
    self.counts[(index % self.period + self.period) % self.period]
  }
}

///|
pub fn deseasonalize(values : Array[Double], period : Int) -> Array[Double] {
  let profile = SeasonalProfile::new(period, alpha=1.0)
  for value in values {
    ignore(profile.update(value))
  }
  let result : Array[Double] = []
  for i, value in values {
    result.push(value - profile.baseline(i))
  }
  result
}

///|
pub fn seasonal_naive_forecast(
  values : Array[Double],
  period : Int,
  horizon : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  let safe_period = if period < 1 { 1 } else { period }
  if values.length() == 0 {
    return result
  }
  for i in 0..<horizon {
    let source = values.length() - safe_period + i % safe_period
    result.push(
      if source >= 0 && source < values.length() {
        values[source]
      } else {
        values[values.length() - 1]
      },
    )
  }
  result
}

///|
pub fn seasonal_strength(values : Array[Double], period : Int) -> Double {
  if values.length() < period * 2 {
    return 0.0
  }
  let residuals = deseasonalize(values, period)
  let total_variance = variance(values)
  if total_variance <= 1.0e-12 {
    0.0
  } else {
    clamp_probability(1.0 - variance(residuals) / total_variance)
  }
}

///|
pub struct SeasonalAnomalyDetector {
  profile : SeasonalProfile
  threshold : Double
  mut index : Int
}

///|
pub fn SeasonalAnomalyDetector::new(
  period : Int,
  threshold? : Double = 3.0,
  alpha? : Double = 0.1,
) -> SeasonalAnomalyDetector {
  {
    profile: SeasonalProfile::new(period, alpha~),
    threshold: if threshold <= 0.0 {
      3.0
    } else {
      threshold
    },
    index: 0,
  }
}

///|
pub fn SeasonalAnomalyDetector::update(
  self : SeasonalAnomalyDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  let residual = self.profile.update(value)
  if self.profile.count(self.index - 1) < 2 {
    return DetectionResult::quiet(index=self.index)
  }
  let scale = 1.0
  let z = absolute(residual) / scale
  DetectionResult::new(
    z >= self.threshold,
    z / self.threshold,
    clamp_probability(z / (z + 1.0)),
    direction_for_delta(residual),
    self.index,
    evidence=residual,
  )
}
