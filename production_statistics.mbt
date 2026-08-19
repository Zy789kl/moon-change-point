///|
/// Statistical test kind used in an evidence report.
pub(all) enum ProductionStatTestKind {
  MeanDifferenceTest
  MedianDifferenceTest
  PermutationShiftTest
  BootstrapIntervalTest
  CorrelationTest
  VarianceRatioTest
}

///|
pub fn production_stat_test_kind_name(kind : ProductionStatTestKind) -> String {
  match kind {
    MeanDifferenceTest => "mean-difference"
    MedianDifferenceTest => "median-difference"
    PermutationShiftTest => "permutation-shift"
    BootstrapIntervalTest => "bootstrap-interval"
    CorrelationTest => "correlation"
    VarianceRatioTest => "variance-ratio"
  }
}

///|
/// Confidence interval for a production effect estimate.
pub struct ProductionConfidenceInterval {
  estimate : Double
  lower : Double
  upper : Double
  confidence : Double
  samples : Int
  test_kind : ProductionStatTestKind
}

///|
pub fn ProductionConfidenceInterval::estimate(
  self : ProductionConfidenceInterval,
) -> Double {
  self.estimate
}

///|
pub fn ProductionConfidenceInterval::lower(
  self : ProductionConfidenceInterval,
) -> Double {
  self.lower
}

///|
pub fn ProductionConfidenceInterval::upper(
  self : ProductionConfidenceInterval,
) -> Double {
  self.upper
}

///|
pub fn ProductionConfidenceInterval::confidence(
  self : ProductionConfidenceInterval,
) -> Double {
  self.confidence
}

///|
pub fn ProductionConfidenceInterval::samples(
  self : ProductionConfidenceInterval,
) -> Int {
  self.samples
}

///|
pub fn ProductionConfidenceInterval::test_kind(
  self : ProductionConfidenceInterval,
) -> ProductionStatTestKind {
  self.test_kind
}

///|
pub fn ProductionConfidenceInterval::contains(
  self : ProductionConfidenceInterval,
  value : Double,
) -> Bool {
  value >= self.lower && value <= self.upper
}

///|
pub fn ProductionConfidenceInterval::width(
  self : ProductionConfidenceInterval,
) -> Double {
  self.upper - self.lower
}

///|
pub fn ProductionConfidenceInterval::summary(
  self : ProductionConfidenceInterval,
) -> String {
  production_stat_test_kind_name(self.test_kind) +
  ":estimate=" +
  self.estimate.to_string() +
  ",lower=" +
  self.lower.to_string() +
  ",upper=" +
  self.upper.to_string() +
  ",confidence=" +
  self.confidence.to_string() +
  ",samples=" +
  self.samples.to_string()
}

///|
/// Test result with a bounded score and actionable interpretation.
pub struct ProductionStatTestResult {
  kind : ProductionStatTestKind
  statistic : Double
  p_value : Double
  effect : Double
  interval : ProductionConfidenceInterval
  significant : Bool
}

///|
pub fn ProductionStatTestResult::kind(
  self : ProductionStatTestResult,
) -> ProductionStatTestKind {
  self.kind
}

///|
pub fn ProductionStatTestResult::statistic(
  self : ProductionStatTestResult,
) -> Double {
  self.statistic
}

///|
pub fn ProductionStatTestResult::p_value(
  self : ProductionStatTestResult,
) -> Double {
  self.p_value
}

///|
pub fn ProductionStatTestResult::effect(
  self : ProductionStatTestResult,
) -> Double {
  self.effect
}

///|
pub fn ProductionStatTestResult::interval(
  self : ProductionStatTestResult,
) -> ProductionConfidenceInterval {
  self.interval
}

///|
pub fn ProductionStatTestResult::significant(
  self : ProductionStatTestResult,
) -> Bool {
  self.significant
}

///|
pub fn ProductionStatTestResult::summary(
  self : ProductionStatTestResult,
) -> String {
  production_stat_test_kind_name(self.kind) +
  ":statistic=" +
  self.statistic.to_string() +
  ",p=" +
  self.p_value.to_string() +
  ",effect=" +
  self.effect.to_string() +
  ",significant=" +
  self.significant.to_string()
}

///|
/// Runs a mean-shift evidence test with a bootstrap interval and permutation p-value.
pub fn production_mean_shift_test(
  left : Array[Double],
  right : Array[Double],
  alpha? : Double = 0.05,
  replicates? : Int = 128,
) -> ProductionStatTestResult {
  let interval = production_bootstrap_difference(left, right, replicates~)
  let p_value = production_permutation_shift_score(
    left,
    right,
    permutations=replicates,
  )
  let effect = production_effect_size(left, right)
  {
    kind: MeanDifferenceTest,
    statistic: absolute(production_mean_difference(left, right)),
    p_value,
    effect,
    interval,
    significant: p_value <= clamp_probability(alpha),
  }
}

///|
/// Runs a median-shift evidence test for heavy-tailed telemetry.
pub fn production_median_shift_test(
  left : Array[Double],
  right : Array[Double],
  alpha? : Double = 0.05,
  replicates? : Int = 128,
) -> ProductionStatTestResult {
  let interval = production_bootstrap_difference(left, right, replicates~)
  let statistic = absolute(production_median_difference(left, right))
  let p_value = production_permutation_shift_score(
    left,
    right,
    permutations=replicates,
  )
  {
    kind: MedianDifferenceTest,
    statistic,
    p_value,
    effect: production_effect_size(left, right),
    interval,
    significant: p_value <= clamp_probability(alpha),
  }
}

///|
pub fn production_mean_difference(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  mean(right) - mean(left)
}

///|
pub fn production_median_difference(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  median(right) - median(left)
}

///|
pub fn production_effect_size(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  let pooled = (
      (left.length() - 1).to_double() * variance(left) +
      (right.length() - 1).to_double() * variance(right)
    ) /
    (left.length() + right.length() - 2).to_double()
  let scale = if pooled <= 1.0e-12 { 1.0 } else { pooled.sqrt() }
  production_mean_difference(left, right) / scale
}

///|
pub fn production_bootstrap_interval(
  values : Array[Double],
  replicates? : Int = 256,
  confidence? : Double = 0.95,
  seed? : Int64 = 17L,
) -> ProductionConfidenceInterval {
  let count = if replicates < 8 { 8 } else { replicates }
  let rng = DeterministicRng::new(seed~)
  let estimates : Array[Double] = []
  for _ in 0..<count {
    let sample : Array[Double] = []
    if values.length() > 0 {
      for _ in 0..<values.length() {
        sample.push(values[(rng.unit() * values.length().to_double()).to_int()])
      }
    }
    estimates.push(mean(sample))
  }
  let alpha = (1.0 - clamp_probability(confidence)) / 2.0
  {
    estimate: mean(values),
    lower: quantile(estimates, alpha),
    upper: quantile(estimates, 1.0 - alpha),
    confidence: clamp_probability(confidence),
    samples: values.length(),
    test_kind: BootstrapIntervalTest,
  }
}

///|
pub fn production_bootstrap_difference(
  left : Array[Double],
  right : Array[Double],
  replicates? : Int = 256,
  confidence? : Double = 0.95,
  seed? : Int64 = 17L,
) -> ProductionConfidenceInterval {
  let count = if replicates < 8 { 8 } else { replicates }
  let rng = DeterministicRng::new(seed~)
  let estimates : Array[Double] = []
  for _ in 0..<count {
    let left_sample : Array[Double] = []
    let right_sample : Array[Double] = []
    for _ in 0..<left.length() {
      if left.length() > 0 {
        left_sample.push(
          left[(rng.unit() * left.length().to_double()).to_int()],
        )
      }
    }
    for _ in 0..<right.length() {
      if right.length() > 0 {
        right_sample.push(
          right[(rng.unit() * right.length().to_double()).to_int()],
        )
      }
    }
    estimates.push(production_mean_difference(left_sample, right_sample))
  }
  let alpha = (1.0 - clamp_probability(confidence)) / 2.0
  {
    estimate: production_mean_difference(left, right),
    lower: quantile(estimates, alpha),
    upper: quantile(estimates, 1.0 - alpha),
    confidence: clamp_probability(confidence),
    samples: left.length() + right.length(),
    test_kind: BootstrapIntervalTest,
  }
}

///|
pub fn production_permutation_shift_score(
  left : Array[Double],
  right : Array[Double],
  permutations? : Int = 128,
  seed? : Int64 = 17L,
) -> Double {
  let observed = absolute(production_mean_difference(left, right))
  let combined : Array[Double] = []
  for value in left {
    combined.push(value)
  }
  for value in right {
    combined.push(value)
  }
  if combined.length() == 0 {
    return 0.0
  }
  let rng = DeterministicRng::new(seed~)
  let mut exceed = 0
  let count = if permutations < 8 { 8 } else { permutations }
  for _ in 0..<count {
    let shuffled : Array[Double] = []
    for value in combined {
      shuffled.push(value)
    }
    for i in 0..<shuffled.length() {
      let j = (rng.unit() * shuffled.length().to_double()).to_int()
      let value = shuffled[i]
      shuffled[i] = shuffled[j]
      shuffled[j] = value
    }
    let left_size = if left.length() > shuffled.length() {
      shuffled.length()
    } else {
      left.length()
    }
    let first : Array[Double] = []
    let second : Array[Double] = []
    for i in 0..<left_size {
      first.push(shuffled[i])
    }
    for i in left_size..<shuffled.length() {
      second.push(shuffled[i])
    }
    if absolute(production_mean_difference(first, second)) >= observed {
      exceed += 1
    }
  }
  (exceed + 1).to_double() / (count + 1).to_double()
}

///|
pub fn production_variance_ratio(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  if variance(left) < 1.0e-12 {
    if variance(right) > 0.0 {
      1.0e6
    } else {
      1.0
    }
  } else {
    variance(right) / variance(left)
  }
}

///|
pub fn production_control_limits(
  baseline : Array[Double],
  sigma_multiplier? : Double = 3.0,
) -> (Double, Double) {
  let center = mean(baseline)
  let width = standard_deviation(baseline) *
    (if sigma_multiplier < 0.0 { 0.0 } else { sigma_multiplier })
  (center - width, center + width)
}

///|
pub fn production_out_of_control_count(
  values : Array[Double],
  lower : Double,
  upper : Double,
) -> Int {
  let mut count = 0
  for value in values {
    if value < lower || value > upper {
      count += 1
    }
  }
  count
}

///|
pub fn production_autocorrelation_profile(
  values : Array[Double],
  maximum_lag? : Int = 16,
) -> Array[Double] {
  let result : Array[Double] = []
  let limit = if maximum_lag < 1 { 1 } else { maximum_lag }
  for lag in 1..<=limit {
    result.push(autocorrelation(values, lag))
  }
  result
}

///|
pub fn production_quantile_profile(
  values : Array[Double],
  probabilities? : Array[Double] = [0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99],
) -> Array[Double] {
  let result : Array[Double] = []
  for probability in probabilities {
    result.push(quantile(values, probability))
  }
  result
}
