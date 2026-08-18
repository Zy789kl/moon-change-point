///|
/// Threshold schedules used when a service changes its noise profile over time.
pub struct ThresholdPoint {
  index : Int
  threshold : Double
  score : Double
  accepted : Bool
}

///|
pub fn ThresholdPoint::new(
  index : Int,
  score : Double,
  threshold : Double,
) -> ThresholdPoint {
  { index, threshold, score, accepted: score >= threshold }
}

///|
pub fn threshold_from_quantile(
  scores : Array[Double],
  false_positive_rate : Double,
) -> Double {
  quantile(scores, 1.0 - clamp_probability(false_positive_rate))
}

///|
pub fn threshold_from_mad(
  scores : Array[Double],
  multiplier? : Double = 3.0,
) -> Double {
  median(scores) + multiplier * median_absolute_deviation(scores) * 1.4826
}

///|
pub fn threshold_from_mean(
  scores : Array[Double],
  standard_deviations? : Double = 3.0,
) -> Double {
  mean(scores) + standard_deviations * standard_deviation(scores)
}

///|
pub fn threshold_grid(
  minimum : Double,
  maximum : Double,
  steps : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  if steps <= 0 {
    return result
  }
  if steps == 1 {
    result.push(minimum)
    return result
  }
  for i in 0..<steps {
    result.push(
      minimum + (maximum - minimum) * i.to_double() / (steps - 1).to_double(),
    )
  }
  result
}

///|
pub fn score_precision(
  scores : Array[Double],
  labels : Array[Bool],
  threshold : Double,
) -> Double {
  let length = if scores.length() < labels.length() {
    scores.length()
  } else {
    labels.length()
  }
  let mut true_positive = 0
  let mut predicted_positive = 0
  for i in 0..<length {
    let predicted = scores[i] >= threshold
    if predicted {
      predicted_positive += 1
    }
    if predicted && labels[i] {
      true_positive += 1
    }
  }
  if predicted_positive == 0 {
    0.0
  } else {
    true_positive.to_double() / predicted_positive.to_double()
  }
}

///|
pub fn score_recall(
  scores : Array[Double],
  labels : Array[Bool],
  threshold : Double,
) -> Double {
  let length = if scores.length() < labels.length() {
    scores.length()
  } else {
    labels.length()
  }
  let mut true_positive = 0
  let mut actual_positive = 0
  for i in 0..<length {
    if labels[i] {
      actual_positive += 1
    }
    if labels[i] && scores[i] >= threshold {
      true_positive += 1
    }
  }
  if actual_positive == 0 {
    1.0
  } else {
    true_positive.to_double() / actual_positive.to_double()
  }
}

///|
pub fn score_f1(
  scores : Array[Double],
  labels : Array[Bool],
  threshold : Double,
) -> Double {
  let precision = score_precision(scores, labels, threshold)
  let recall = score_recall(scores, labels, threshold)
  if precision + recall == 0.0 {
    0.0
  } else {
    2.0 * precision * recall / (precision + recall)
  }
}

///|
pub fn best_f1_threshold(
  scores : Array[Double],
  labels : Array[Bool],
  candidates : Array[Double],
) -> ThresholdPoint {
  if candidates.length() == 0 {
    return ThresholdPoint::new(0, 0.0, 0.0)
  }
  let mut best = ThresholdPoint::new(
    0,
    score_f1(scores, labels, candidates[0]),
    candidates[0],
  )
  for i in 1..<candidates.length() {
    let candidate = candidates[i]
    let f1 = score_f1(scores, labels, candidate)
    if f1 > best.score {
      best = { index: i, threshold: candidate, score: f1, accepted: true }
    }
  }
  best
}

///|
pub struct AdaptiveThreshold {
  mut threshold : Double
  rate : Double
  minimum : Double
  maximum : Double
  mut count : Int
}

///|
pub fn AdaptiveThreshold::new(
  initial? : Double = 1.0,
  rate? : Double = 0.05,
  minimum? : Double = 0.0,
  maximum? : Double = 1.7976931348623157e308,
) -> AdaptiveThreshold {
  {
    threshold: if initial < minimum {
      minimum
    } else if initial > maximum {
      maximum
    } else {
      initial
    },
    rate: clamp_probability(rate),
    minimum,
    maximum,
    count: 0,
  }
}

///|
pub fn AdaptiveThreshold::observe(
  self : AdaptiveThreshold,
  score : Double,
  positive : Bool,
) -> Double {
  self.count += 1
  let error = if positive { 1.0 - score } else { score }
  self.threshold += self.rate * (if positive { -error } else { error })
  if self.threshold < self.minimum {
    self.threshold = self.minimum
  }
  if self.threshold > self.maximum {
    self.threshold = self.maximum
  }
  self.threshold
}

///|
pub fn AdaptiveThreshold::value(self : AdaptiveThreshold) -> Double {
  self.threshold
}

///|
pub fn AdaptiveThreshold::count(self : AdaptiveThreshold) -> Int {
  self.count
}

///|
pub fn threshold_points(
  scores : Array[Double],
  threshold : Double,
) -> Array[ThresholdPoint] {
  let result : Array[ThresholdPoint] = []
  for i, score in scores {
    result.push(ThresholdPoint::new(i, score, threshold))
  }
  result
}
