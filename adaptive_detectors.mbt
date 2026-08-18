///|
/// A slowly adapting baseline for streams whose normal level changes over time.
pub struct AdaptiveBaseline {
  moments : OnlineMoments
  mut value : Double
  learning_rate : Double
  mut initialized : Bool
}

///|
pub fn AdaptiveBaseline::new(
  learning_rate? : Double = 0.05,
) -> AdaptiveBaseline {
  {
    moments: OnlineMoments::new(),
    value: 0.0,
    learning_rate: clamp_probability(learning_rate),
    initialized: false,
  }
}

///|
pub fn AdaptiveBaseline::update(
  self : AdaptiveBaseline,
  observation : Double,
) -> Double {
  if !is_finite(observation) {
    return self.value
  }
  if !self.initialized {
    self.value = observation
    self.initialized = true
  } else {
    self.value = self.value + self.learning_rate * (observation - self.value)
  }
  self.moments.push(observation)
  self.value
}

///|
pub fn AdaptiveBaseline::value(self : AdaptiveBaseline) -> Double {
  self.value
}

///|
pub fn AdaptiveBaseline::sample_count(self : AdaptiveBaseline) -> Int {
  self.moments.count()
}

///|
pub fn AdaptiveBaseline::summary(self : AdaptiveBaseline) -> StatsSummary {
  self.moments.summary()
}

///|
/// EWMA residual detector. It is useful for low-latency monitoring of a service metric.
pub struct EwmaDetector {
  mut baseline : Double
  mut variance : Double
  alpha : Double
  threshold : Double
  warmup : Int
  mut count : Int
  mut index : Int
  mut initialized : Bool
}

///|
pub fn EwmaDetector::new(
  alpha? : Double = 0.2,
  threshold? : Double = 3.0,
  warmup? : Int = 8,
  initial_mean? : Double = 0.0,
  initial_variance? : Double = 1.0,
) -> EwmaDetector {
  {
    baseline: initial_mean,
    variance: if initial_variance > 0.0 {
      initial_variance
    } else {
      1.0
    },
    alpha: clamp_probability(alpha),
    threshold: if threshold > 0.0 {
      threshold
    } else {
      1.0
    },
    warmup: if warmup < 0 {
      0
    } else {
      warmup
    },
    count: 0,
    index: 0,
    initialized: false,
  }
}

///|
pub fn EwmaDetector::reset(self : EwmaDetector) -> Unit {
  self.count = 0
  self.index = 0
  self.initialized = false
}

///|
pub fn EwmaDetector::baseline(self : EwmaDetector) -> Double {
  self.baseline
}

///|
pub fn EwmaDetector::scale(self : EwmaDetector) -> Double {
  self.variance.sqrt()
}

///|
fn direction_for_delta(
  delta : Double,
  variance_change? : Bool = false,
) -> ChangeDirection {
  if variance_change {
    if delta >= 0.0 {
      VarianceIncrease
    } else {
      VarianceDecrease
    }
  } else if delta > 0.0 {
    Increase
  } else if delta < 0.0 {
    Decrease
  } else {
    Unknown
  }
}

///|
pub fn EwmaDetector::update(
  self : EwmaDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  self.count += 1
  if !self.initialized {
    self.baseline = value
    self.initialized = true
    return DetectionResult::quiet(index=self.index)
  }
  let old_baseline = self.baseline
  let residual = value - old_baseline
  let alpha = self.alpha
  self.baseline = old_baseline + alpha * residual
  self.variance = (1.0 - alpha) * (self.variance + alpha * residual * residual)
  let scale = if self.variance.sqrt() < 1.0e-12 {
    1.0e-12
  } else {
    self.variance.sqrt()
  }
  let score = absolute(residual) / (self.threshold * scale)
  let confidence = clamp_probability(
    1.0 - @math.exp(-absolute(residual) / scale),
  )
  let changed = self.count > self.warmup && score >= 1.0
  DetectionResult::new(
    changed,
    score,
    confidence,
    direction_for_delta(residual),
    self.index,
    evidence=residual,
  )
}

///|
/// Detects variance changes by comparing short and long rolling windows.
pub struct VarianceShiftDetector {
  short_window : DoubleWindow
  long_window : DoubleWindow
  threshold : Double
  warmup : Int
  mut index : Int
}

///|
pub fn VarianceShiftDetector::new(
  short_window? : Int = 8,
  long_window? : Int = 32,
  threshold? : Double = 1.8,
) -> VarianceShiftDetector {
  let safe_short = if short_window < 2 { 2 } else { short_window }
  let safe_long = if long_window <= safe_short {
    safe_short * 2
  } else {
    long_window
  }
  {
    short_window: DoubleWindow::new(safe_short),
    long_window: DoubleWindow::new(safe_long),
    threshold: if threshold < 1.0 {
      1.0
    } else {
      threshold
    },
    warmup: safe_long,
    index: 0,
  }
}

///|
pub fn VarianceShiftDetector::reset(self : VarianceShiftDetector) -> Unit {
  self.short_window.clear()
  self.long_window.clear()
  self.index = 0
}

///|
pub fn VarianceShiftDetector::update(
  self : VarianceShiftDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  ignore(self.short_window.push(value))
  ignore(self.long_window.push(value))
  if self.long_window.length() < self.warmup || self.short_window.length() < 2 {
    return DetectionResult::quiet(index=self.index)
  }
  let short_variance = self.short_window.variance()
  let long_variance = self.long_window.variance()
  if long_variance <= 1.0e-12 {
    return DetectionResult::quiet(index=self.index)
  }
  let ratio = short_variance / long_variance
  let increase = ratio >= self.threshold
  let decrease = ratio <= 1.0 / self.threshold
  let distance = if increase {
    ratio / self.threshold
  } else if decrease {
    1.0 / ratio / self.threshold
  } else {
    0.0
  }
  let score = if distance > 0.0 { distance } else { 0.0 }
  DetectionResult::new(
    increase || decrease,
    score,
    clamp_probability(score / 2.0),
    if increase {
      VarianceIncrease
    } else {
      VarianceDecrease
    },
    self.index,
    evidence=ratio,
  )
}

///|
/// A robust detector based on the rolling median and MAD.
pub struct RobustZDetector {
  window : DoubleWindow
  threshold : Double
  warmup : Int
  mut index : Int
}

///|
pub fn RobustZDetector::new(
  window_size? : Int = 25,
  threshold? : Double = 3.5,
) -> RobustZDetector {
  let size = if window_size < 3 { 3 } else { window_size }
  {
    window: DoubleWindow::new(size),
    threshold: if threshold <= 0.0 {
      3.5
    } else {
      threshold
    },
    warmup: if size / 2 < 3 {
      3
    } else {
      size / 2
    },
    index: 0,
  }
}

///|
pub fn RobustZDetector::reset(self : RobustZDetector) -> Unit {
  self.window.clear()
  self.index = 0
}

///|
pub fn RobustZDetector::update(
  self : RobustZDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  ignore(self.window.push(value))
  if self.window.length() < self.warmup {
    return DetectionResult::quiet(index=self.index)
  }
  let values = self.window.to_array()
  let center = median(values)
  let mad = median_absolute_deviation(values)
  let scale = if mad < 1.0e-12 { 1.0e-12 } else { 1.4826 * mad }
  let z = absolute(value - center) / scale
  let score = z / self.threshold
  DetectionResult::new(
    z >= self.threshold,
    score,
    clamp_probability(1.0 - @math.exp(-z / 2.0)),
    direction_for_delta(value - center),
    self.index,
    evidence=z,
  )
}

///|
/// Detects a sustained slope rather than a one-point spike.
pub struct TrendShiftDetector {
  window : DoubleWindow
  slope_threshold : Double
  persistence : Int
  mut consecutive : Int
  mut index : Int
}

///|
pub fn TrendShiftDetector::new(
  window_size? : Int = 16,
  slope_threshold? : Double = 0.1,
  persistence? : Int = 3,
) -> TrendShiftDetector {
  {
    window: DoubleWindow::new(if window_size < 3 { 3 } else { window_size }),
    slope_threshold: if slope_threshold <= 0.0 {
      0.1
    } else {
      slope_threshold
    },
    persistence: if persistence < 1 {
      1
    } else {
      persistence
    },
    consecutive: 0,
    index: 0,
  }
}

///|
pub fn TrendShiftDetector::reset(self : TrendShiftDetector) -> Unit {
  self.window.clear()
  self.consecutive = 0
  self.index = 0
}

///|
pub fn TrendShiftDetector::update(
  self : TrendShiftDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  ignore(self.window.push(value))
  if self.window.length() < self.window.capacity() {
    return DetectionResult::quiet(index=self.index)
  }
  let slope = self.window.slope()
  if absolute(slope) >= self.slope_threshold {
    self.consecutive += 1
  } else {
    self.consecutive = 0
  }
  let score = absolute(slope) / self.slope_threshold
  DetectionResult::new(
    self.consecutive >= self.persistence,
    score,
    clamp_probability(score / 2.0),
    direction_for_delta(slope),
    self.index,
    evidence=slope,
  )
}

///|
/// A lightweight detector for isolated spikes using a rolling interquartile fence.
pub struct IqrSpikeDetector {
  window : DoubleWindow
  multiplier : Double
  warmup : Int
  mut index : Int
}

///|
pub fn IqrSpikeDetector::new(
  window_size? : Int = 25,
  multiplier? : Double = 1.5,
) -> IqrSpikeDetector {
  let size = if window_size < 4 { 4 } else { window_size }
  {
    window: DoubleWindow::new(size),
    multiplier: if multiplier <= 0.0 {
      1.5
    } else {
      multiplier
    },
    warmup: size / 2,
    index: 0,
  }
}

///|
pub fn IqrSpikeDetector::update(
  self : IqrSpikeDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  ignore(self.window.push(value))
  if self.window.length() < self.warmup {
    return DetectionResult::quiet(index=self.index)
  }
  let values = self.window.to_array()
  let q1 = quantile(values, 0.25)
  let q3 = quantile(values, 0.75)
  let spread = q3 - q1
  let distance = if value < q1 {
    q1 - value
  } else if value > q3 {
    value - q3
  } else {
    0.0
  }
  let fence_distance = self.multiplier * spread
  let score = if fence_distance <= 1.0e-12 {
    if distance > 0.0 {
      1.0
    } else {
      0.0
    }
  } else {
    distance / fence_distance
  }
  DetectionResult::new(
    score >= 1.0,
    score,
    clamp_probability(score / 2.0),
    direction_for_delta(value - median(values)),
    self.index,
    evidence=distance,
  )
}
