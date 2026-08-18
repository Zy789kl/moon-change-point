///|
/// Features extracted from a bounded window for dashboards and model input.
pub struct WindowFeatures {
  count : Int
  mean : Double
  standard_deviation : Double
  median : Double
  mad : Double
  minimum : Double
  maximum : Double
  range : Double
  slope : Double
  autocorrelation : Double
  change_rate : Double
}

///|
pub fn WindowFeatures::empty() -> WindowFeatures {
  {
    count: 0,
    mean: 0.0,
    standard_deviation: 0.0,
    median: 0.0,
    mad: 0.0,
    minimum: 0.0,
    maximum: 0.0,
    range: 0.0,
    slope: 0.0,
    autocorrelation: 0.0,
    change_rate: 0.0,
  }
}

///|
pub fn extract_features(values : Array[Double]) -> WindowFeatures {
  if values.length() == 0 {
    return WindowFeatures::empty()
  }
  {
    count: values.length(),
    mean: mean(values),
    standard_deviation: standard_deviation(values),
    median: median(values),
    mad: median_absolute_deviation(values),
    minimum: array_minimum(values),
    maximum: array_maximum(values),
    range: array_maximum(values) - array_minimum(values),
    slope: linear_slope(values),
    autocorrelation: autocorrelation(values, 1),
    change_rate: sign_change_rate(values),
  }
}

///|
pub fn feature_distance(
  left : WindowFeatures,
  right : WindowFeatures,
) -> Double {
  let mean_scale = 1.0 + absolute(left.mean) + absolute(right.mean)
  let scale_scale = 1.0 + left.standard_deviation + right.standard_deviation
  let slope_scale = 1.0 + absolute(left.slope) + absolute(right.slope)
  let a = absolute(left.mean - right.mean) / mean_scale
  let b = absolute(left.standard_deviation - right.standard_deviation) /
    scale_scale
  let c = absolute(left.median - right.median) / mean_scale
  let d = absolute(left.slope - right.slope) / slope_scale
  (a + b + c + d) / 4.0
}

///|
pub fn feature_change_score(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  feature_distance(extract_features(left), extract_features(right))
}

///|
pub struct FeatureExtractor {
  left : DoubleWindow
  right : DoubleWindow
  threshold : Double
  mut index : Int
}

///|
pub fn FeatureExtractor::new(
  window_size? : Int = 16,
  threshold? : Double = 0.25,
) -> FeatureExtractor {
  let size = if window_size < 2 { 2 } else { window_size }
  {
    left: DoubleWindow::new(size),
    right: DoubleWindow::new(size),
    threshold: if threshold <= 0.0 {
      0.25
    } else {
      threshold
    },
    index: 0,
  }
}

///|
pub fn FeatureExtractor::update(
  self : FeatureExtractor,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  if self.right.is_full() {
    self.left.clear()
    for item in self.right.to_array() {
      ignore(self.left.push(item))
    }
    self.right.clear()
  }
  ignore(self.right.push(value))
  if !self.left.is_full() || !self.right.is_full() {
    return DetectionResult::quiet(index=self.index)
  }
  let score = feature_change_score(self.left.to_array(), self.right.to_array())
  DetectionResult::new(
    score >= self.threshold,
    score / self.threshold,
    clamp_probability(score),
    DistributionShift,
    self.index,
    evidence=score,
  )
}

///|
pub fn feature_names() -> Array[String] {
  [
    "count", "mean", "standard_deviation", "median", "mad", "minimum", "maximum",
    "range", "slope", "autocorrelation", "change_rate",
  ]
}
