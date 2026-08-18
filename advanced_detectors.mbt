///|
/// Detects a persistent step change by comparing a reference and a current block.
pub struct StepChangeDetector {
  reference : DoubleWindow
  current : DoubleWindow
  threshold : Double
  mut index : Int
}

///|
pub fn StepChangeDetector::new(
  window_size? : Int = 16,
  threshold? : Double = 3.0,
) -> StepChangeDetector {
  let size = if window_size < 2 { 2 } else { window_size }
  {
    reference: DoubleWindow::new(size),
    current: DoubleWindow::new(size),
    threshold: if threshold <= 0.0 {
      3.0
    } else {
      threshold
    },
    index: 0,
  }
}

///|
pub fn StepChangeDetector::update(
  self : StepChangeDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  if self.current.is_full() {
    self.reference.clear()
    for item in self.current.to_array() {
      ignore(self.reference.push(item))
    }
    self.current.clear()
  }
  ignore(self.current.push(value))
  if !self.reference.is_full() || !self.current.is_full() {
    return DetectionResult::quiet(index=self.index)
  }
  let score = mean_shift_score(
    self.reference.to_array() + self.current.to_array(),
    self.reference.length(),
    min_segment=self.reference.length() / 2,
  )
  let direction = direction_for_delta(
    self.current.mean() - self.reference.mean(),
  )
  DetectionResult::new(
    score >= self.threshold,
    score / self.threshold,
    clamp_probability(score / (score + 1.0)),
    direction,
    self.index,
    evidence=score,
  )
}

///|
pub struct MeanVarianceDetector {
  baseline : DoubleWindow
  current : DoubleWindow
  mean_threshold : Double
  variance_threshold : Double
  mut index : Int
}

///|
pub fn MeanVarianceDetector::new(
  window_size? : Int = 16,
  mean_threshold? : Double = 2.0,
  variance_threshold? : Double = 2.0,
) -> MeanVarianceDetector {
  let size = if window_size < 2 { 2 } else { window_size }
  {
    baseline: DoubleWindow::new(size),
    current: DoubleWindow::new(size),
    mean_threshold: if mean_threshold <= 0.0 {
      2.0
    } else {
      mean_threshold
    },
    variance_threshold: if variance_threshold <= 1.0 {
      2.0
    } else {
      variance_threshold
    },
    index: 0,
  }
}

///|
pub fn MeanVarianceDetector::update(
  self : MeanVarianceDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  if self.current.is_full() {
    self.baseline.clear()
    for item in self.current.to_array() {
      ignore(self.baseline.push(item))
    }
    self.current.clear()
  }
  ignore(self.current.push(value))
  if !self.baseline.is_full() || !self.current.is_full() {
    return DetectionResult::quiet(index=self.index)
  }
  let mean_scale = self.baseline.standard_deviation() + 1.0e-12
  let mean_score = absolute(self.current.mean() - self.baseline.mean()) /
    mean_scale
  let base_variance = self.baseline.variance() + 1.0e-12
  let ratio = self.current.variance() / base_variance
  let variance_score = if ratio >= 1.0 {
    ratio / self.variance_threshold
  } else {
    1.0 / ratio / self.variance_threshold
  }
  let score = if mean_score > variance_score {
    mean_score / self.mean_threshold
  } else {
    variance_score
  }
  let direction = if mean_score > variance_score {
    direction_for_delta(self.current.mean() - self.baseline.mean())
  } else if ratio >= 1.0 {
    VarianceIncrease
  } else {
    VarianceDecrease
  }
  DetectionResult::new(
    score >= 1.0,
    score,
    clamp_probability(score / (score + 1.0)),
    direction,
    self.index,
    evidence=ratio,
  )
}

///|
pub struct DualSidedDetector {
  positive : Cusum
  negative : Cusum
  mut index : Int
}

///|
pub fn DualSidedDetector::new(
  target? : Double = 0.0,
  limit? : Double = 5.0,
  drift? : Double = 0.5,
) -> DualSidedDetector {
  {
    positive: Cusum::new(target_mean=target, control_limit=limit, drift~),
    negative: Cusum::new(target_mean=target, control_limit=limit, drift~),
    index: 0,
  }
}

///|
pub fn DualSidedDetector::update(
  self : DualSidedDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  let positive = self.positive.update_result(value, index=self.index)
  let negative = self.negative.update_result(-value, index=self.index)
  if positive.score > negative.score {
    positive
  } else {
    {
      changed: negative.changed,
      score: negative.score,
      confidence: negative.confidence,
      direction: if negative.changed {
        Decrease
      } else {
        Unknown
      },
      index: self.index,
      evidence: negative.evidence,
    }
  }
}

///|
pub struct PersistenceDetector {
  detector : EwmaDetector
  rule : ConsecutiveRule
  mut index : Int
}

///|
pub fn PersistenceDetector::new(
  warmup? : Int = 8,
  persistence? : Int = 3,
) -> PersistenceDetector {
  {
    detector: EwmaDetector::new(warmup~),
    rule: ConsecutiveRule::new(required=persistence),
    index: 0,
  }
}

///|
pub fn PersistenceDetector::update(
  self : PersistenceDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  let result = self.detector.update(value)
  let changed = self.rule.push(result.changed)
  {
    changed,
    score: result.score,
    confidence: result.confidence,
    direction: result.direction,
    index: self.index,
    evidence: result.evidence,
  }
}
