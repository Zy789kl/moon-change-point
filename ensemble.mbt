///|
pub struct EnsembleResult {
  result : DetectionResult
  votes : Int
  detector_count : Int
  agreement : Double
}

///|
pub struct OnlineEnsemble {
  detectors : Array[PipelineDetector]
  quorum : Int
  mut index : Int
}

///|
pub fn OnlineEnsemble::new(
  detectors : Array[PipelineDetector],
  quorum? : Int = 1,
) -> OnlineEnsemble {
  let safe_quorum = if quorum < 1 {
    1
  } else if quorum > detectors.length() {
    detectors.length()
  } else {
    quorum
  }
  { detectors, quorum: safe_quorum, index: 0 }
}

///|
pub fn OnlineEnsemble::count(self : OnlineEnsemble) -> Int {
  self.detectors.length()
}

///|
pub fn OnlineEnsemble::update(
  self : OnlineEnsemble,
  value : Double,
) -> EnsembleResult {
  self.index += 1
  let mut votes = 0
  let mut best = DetectionResult::quiet(index=self.index)
  for detector in self.detectors {
    let result = detector.update(value, self.index)
    if result.changed {
      votes += 1
    }
    if result.score > best.score {
      best = result
    }
  }
  let agreement = if self.detectors.length() == 0 {
    0.0
  } else {
    votes.to_double() / self.detectors.length().to_double()
  }
  {
    result: {
      changed: votes >= self.quorum,
      score: best.score,
      confidence: agreement * best.confidence,
      direction: best.direction,
      index: self.index,
      evidence: agreement,
    },
    votes,
    detector_count: self.detectors.length(),
    agreement,
  }
}

///|
pub fn weighted_consensus(
  results : Array[DetectionResult],
  weights : Array[Double],
  quorum : Double,
) -> DetectionResult {
  if results.length() == 0 {
    return DetectionResult::quiet()
  }
  let score = combine_scores(results.map(r => r.score), weights)
  let mut changed_weight = 0.0
  let mut best = results[0]
  for i in 0..<results.length() {
    if i < weights.length() && results[i].changed {
      changed_weight += weights[i]
    }
    if results[i].score > best.score {
      best = results[i]
    }
  }
  let total_weight = sum(weights)
  let agreement = if total_weight == 0.0 {
    0.0
  } else {
    changed_weight / total_weight
  }
  {
    changed: agreement >= quorum,
    score,
    confidence: agreement * best.confidence,
    direction: best.direction,
    index: best.index,
    evidence: agreement,
  }
}

///|
pub fn detector_reliability(results : Array[DetectionResult]) -> Double {
  if results.length() == 0 {
    return 0.0
  }
  let mut confident = 0
  for result in results {
    if result.confidence >= 0.5 {
      confident += 1
    }
  }
  confident.to_double() / results.length().to_double()
}
