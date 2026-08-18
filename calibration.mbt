///|
/// Stores labeled detector scores for threshold selection.
pub struct ScoreObservation {
  score : Double
  changed : Bool
  weight : Double
}

///|
pub fn ScoreObservation::new(
  score : Double,
  changed : Bool,
  weight? : Double = 1.0,
) -> ScoreObservation {
  { score, changed, weight: if weight <= 0.0 { 1.0 } else { weight } }
}

///|
pub struct ThresholdReport {
  threshold : Double
  true_positives : Int
  false_positives : Int
  true_negatives : Int
  false_negatives : Int
  precision : Double
  recall : Double
  f1 : Double
  expected_cost : Double
}

///|
pub fn ThresholdReport::empty(threshold : Double) -> ThresholdReport {
  {
    threshold,
    true_positives: 0,
    false_positives: 0,
    true_negatives: 0,
    false_negatives: 0,
    precision: 0.0,
    recall: 0.0,
    f1: 0.0,
    expected_cost: 0.0,
  }
}

///|
pub fn evaluate_threshold(
  observations : Array[ScoreObservation],
  threshold : Double,
  false_positive_cost? : Double = 1.0,
  false_negative_cost? : Double = 4.0,
) -> ThresholdReport {
  let mut true_positives = 0
  let mut false_positives = 0
  let mut true_negatives = 0
  let mut false_negatives = 0
  for observation in observations {
    let predicted = observation.score >= threshold
    if predicted && observation.changed {
      true_positives += 1
    } else if predicted {
      false_positives += 1
    } else if observation.changed {
      false_negatives += 1
    } else {
      true_negatives += 1
    }
  }
  let precision = if true_positives + false_positives == 0 {
    0.0
  } else {
    true_positives.to_double() / (true_positives + false_positives).to_double()
  }
  let recall = if true_positives + false_negatives == 0 {
    0.0
  } else {
    true_positives.to_double() / (true_positives + false_negatives).to_double()
  }
  let f1 = if precision + recall == 0.0 {
    0.0
  } else {
    2.0 * precision * recall / (precision + recall)
  }
  {
    threshold,
    true_positives,
    false_positives,
    true_negatives,
    false_negatives,
    precision,
    recall,
    f1,
    expected_cost: false_positives.to_double() * false_positive_cost +
    false_negatives.to_double() * false_negative_cost,
  }
}

///|
pub fn best_threshold(
  observations : Array[ScoreObservation],
  candidates : Array[Double],
  false_positive_cost? : Double = 1.0,
  false_negative_cost? : Double = 4.0,
) -> ThresholdReport {
  let mut best = ThresholdReport::empty(
    if candidates.length() == 0 {
      1.0
    } else {
      candidates[0]
    },
  )
  for candidate in candidates {
    let report = evaluate_threshold(
      observations,
      candidate,
      false_positive_cost~,
      false_negative_cost~,
    )
    if report.f1 > best.f1 ||
      (report.f1 == best.f1 && report.expected_cost < best.expected_cost) {
      best = report
    }
  }
  best
}

///|
pub struct ScoreCalibrator {
  observations : Array[ScoreObservation]
  max_observations : Int
  mut positive_weight : Double
  mut negative_weight : Double
}

///|
pub fn ScoreCalibrator::new(max_observations? : Int = 4096) -> ScoreCalibrator {
  {
    observations: [],
    max_observations: if max_observations < 1 {
      1
    } else {
      max_observations
    },
    positive_weight: 0.0,
    negative_weight: 0.0,
  }
}

///|
pub fn ScoreCalibrator::push(
  self : ScoreCalibrator,
  score : Double,
  changed : Bool,
  weight? : Double = 1.0,
) -> Unit {
  let safe_weight = if weight <= 0.0 { 1.0 } else { weight }
  let item = {
    score: if score < 0.0 {
      0.0
    } else {
      score
    },
    changed,
    weight: safe_weight,
  }
  self.observations.push(item)
  if changed {
    self.positive_weight += safe_weight
  } else {
    self.negative_weight += safe_weight
  }
  if self.observations.length() > self.max_observations {
    ignore(self.observations.remove(0))
  }
}

///|
pub fn ScoreCalibrator::count(self : ScoreCalibrator) -> Int {
  self.observations.length()
}

///|
pub fn ScoreCalibrator::positive_weight(self : ScoreCalibrator) -> Double {
  self.positive_weight
}

///|
pub fn ScoreCalibrator::negative_weight(self : ScoreCalibrator) -> Double {
  self.negative_weight
}

///|
pub fn ScoreCalibrator::report(
  self : ScoreCalibrator,
  threshold : Double,
) -> ThresholdReport {
  evaluate_threshold(self.observations, threshold)
}

///|
pub fn ScoreCalibrator::best(
  self : ScoreCalibrator,
  candidates : Array[Double],
) -> ThresholdReport {
  best_threshold(self.observations, candidates)
}

///|
pub fn calibration_bins(
  observations : Array[ScoreObservation],
  bins? : Int = 10,
) -> Array[Double] {
  let size = if bins < 1 { 1 } else { bins }
  let positives = Array::make(size, 0.0)
  let totals = Array::make(size, 0.0)
  for observation in observations {
    let index = if observation.score >= 1.0 {
      size - 1
    } else {
      (observation.score * size.to_double()).to_int()
    }
    totals[index] += observation.weight
    if observation.changed {
      positives[index] += observation.weight
    }
  }
  let result : Array[Double] = []
  for i in 0..<size {
    result.push(if totals[i] == 0.0 { 0.0 } else { positives[i] / totals[i] })
  }
  result
}
