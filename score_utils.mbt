///|
pub fn sigmoid_score(value : Double) -> Double {
  if value >= 0.0 {
    1.0 / (1.0 + @math.exp(-value))
  } else {
    let exp_value = @math.exp(value)
    exp_value / (1.0 + exp_value)
  }
}

///|
pub fn tail_confidence(score : Double, scale? : Double = 1.0) -> Double {
  let safe_scale = if scale <= 0.0 { 1.0 } else { scale }
  clamp_probability(1.0 - @math.exp(-absolute(score) / safe_scale))
}

///|
pub fn combine_scores(
  scores : Array[Double],
  weights : Array[Double],
) -> Double {
  let length = if scores.length() < weights.length() {
    scores.length()
  } else {
    weights.length()
  }
  let mut total = 0.0
  let mut weight_total = 0.0
  for i in 0..<length {
    let weight = if weights[i] < 0.0 { 0.0 } else { weights[i] }
    total += scores[i] * weight
    weight_total += weight
  }
  if weight_total == 0.0 {
    0.0
  } else {
    total / weight_total
  }
}

///|
pub fn score_margin(score : Double, threshold : Double) -> Double {
  score - threshold
}

///|
pub fn score_to_confidence(score : Double, threshold : Double) -> Double {
  if threshold <= 0.0 {
    tail_confidence(score)
  } else {
    sigmoid_score(score - threshold)
  }
}

///|
pub fn expected_alert_cost(
  false_positive_rate : Double,
  false_negative_rate : Double,
  false_positive_cost? : Double = 1.0,
  false_negative_cost? : Double = 4.0,
) -> Double {
  clamp_probability(false_positive_rate) * false_positive_cost +
  clamp_probability(false_negative_rate) * false_negative_cost
}

///|
pub fn threshold_for_false_positive(
  scores : Array[Double],
  target_rate : Double,
) -> Double {
  if scores.length() == 0 {
    return 0.0
  }
  quantile(scores, 1.0 - clamp_probability(target_rate))
}

///|
pub fn normalize_scores(scores : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  let maximum = array_maximum(scores)
  let minimum = array_minimum(scores)
  let range = maximum - minimum
  for score in scores {
    result.push(if range <= 1.0e-12 { 0.0 } else { (score - minimum) / range })
  }
  result
}
