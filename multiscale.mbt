///|
/// Evidence at multiple temporal scales.
pub struct ScaleEvidence {
  short_score : Double
  medium_score : Double
  long_score : Double
  consensus : Double
  changed : Bool
}

///|
pub fn ScaleEvidence::empty() -> ScaleEvidence {
  {
    short_score: 0.0,
    medium_score: 0.0,
    long_score: 0.0,
    consensus: 0.0,
    changed: false,
  }
}

///|
pub struct MultiScaleDetector {
  short : RobustZDetector
  medium : RobustZDetector
  long : TrendShiftDetector
  minimum_consensus : Double
  mut index : Int
}

///|
pub fn MultiScaleDetector::new(
  short? : Int = 8,
  medium? : Int = 24,
  long? : Int = 48,
  minimum_consensus? : Double = 0.5,
) -> MultiScaleDetector {
  {
    short: RobustZDetector::new(window_size=short),
    medium: RobustZDetector::new(window_size=medium),
    long: TrendShiftDetector::new(window_size=long),
    minimum_consensus: clamp_probability(minimum_consensus),
    index: 0,
  }
}

///|
pub fn MultiScaleDetector::update(
  self : MultiScaleDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  let short_result = self.short.update(value)
  let medium_result = self.medium.update(value)
  let long_result = self.long.update(value)
  let mut votes = 0
  if short_result.changed {
    votes += 1
  }
  if medium_result.changed {
    votes += 1
  }
  if long_result.changed {
    votes += 1
  }
  let consensus = votes.to_double() / 3.0
  let best = if short_result.score > medium_result.score {
    if short_result.score > long_result.score {
      short_result
    } else {
      long_result
    }
  } else if medium_result.score > long_result.score {
    medium_result
  } else {
    long_result
  }
  {
    changed: consensus >= self.minimum_consensus,
    score: best.score,
    confidence: clamp_probability(consensus * best.confidence),
    direction: best.direction,
    index: self.index,
    evidence: consensus,
  }
}

///|
pub fn scale_profile(
  values : Array[Double],
  sizes : Array[Int],
) -> Array[ScaleEvidence] {
  let result : Array[ScaleEvidence] = []
  for size in sizes {
    let window = DoubleWindow::new(size)
    let mut previous = 0.0
    let mut score = 0.0
    for value in values {
      ignore(window.push(value))
      score = absolute(window.mean() - previous)
      previous = window.mean()
    }
    result.push({
      short_score: score,
      medium_score: window.standard_deviation(),
      long_score: window.slope(),
      consensus: clamp_probability(score),
      changed: score > 0.0,
    })
  }
  result
}

///|
pub fn adaptive_threshold(
  scores : Array[Double],
  false_positive_rate? : Double = 0.05,
) -> Double {
  threshold_for_false_positive(scores, false_positive_rate)
}

///|
pub fn consensus_score(results : Array[DetectionResult]) -> Double {
  if results.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for result in results {
    total += if result.changed { 1.0 } else { 0.0 }
  }
  total / results.length().to_double()
}
