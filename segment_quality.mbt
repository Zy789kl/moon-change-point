///|
/// Segment-level diagnostics used to decide whether a change is actionable.
pub struct SegmentQuality {
  count : Int
  mean : Double
  deviation : Double
  stability : Double
  completeness : Double
  score : Double
}

///|
pub fn SegmentQuality::empty() -> SegmentQuality {
  {
    count: 0,
    mean: 0.0,
    deviation: 0.0,
    stability: 0.0,
    completeness: 0.0,
    score: 0.0,
  }
}

///|
pub fn segment_quality(values : Array[Double]) -> SegmentQuality {
  if values.length() == 0 {
    return SegmentQuality::empty()
  }
  let valid = values.filter(fn(value) { is_finite(value) })
  if valid.length() == 0 {
    return SegmentQuality::empty()
  }
  let deviation = standard_deviation(valid)
  let stability = 1.0 / (1.0 + deviation)
  let completeness = valid.length().to_double() / values.length().to_double()
  let score = clamp_probability(stability * completeness)
  {
    count: valid.length(),
    mean: mean(valid),
    deviation,
    stability,
    completeness,
    score,
  }
}

///|
pub fn compare_segment_quality(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  let a = segment_quality(left)
  let b = segment_quality(right)
  absolute(a.score - b.score)
}

///|
pub fn segment_means(
  values : Array[Double],
  boundaries : Array[Int],
) -> Array[Double] {
  let result : Array[Double] = []
  let mut start = 0
  for boundary in boundaries {
    let end = if boundary < start {
      start
    } else if boundary > values.length() {
      values.length()
    } else {
      boundary
    }
    let part : Array[Double] = []
    for i in start..<end {
      part.push(values[i])
    }
    result.push(mean(part))
    start = end
  }
  let tail : Array[Double] = []
  for i in start..<values.length() {
    tail.push(values[i])
  }
  result.push(mean(tail))
  result
}

///|
pub fn segment_variances(
  values : Array[Double],
  boundaries : Array[Int],
) -> Array[Double] {
  let result : Array[Double] = []
  let mut start = 0
  for boundary in boundaries {
    let end = if boundary < start {
      start
    } else if boundary > values.length() {
      values.length()
    } else {
      boundary
    }
    let part : Array[Double] = []
    for i in start..<end {
      part.push(values[i])
    }
    result.push(variance(part))
    start = end
  }
  let tail : Array[Double] = []
  for i in start..<values.length() {
    tail.push(values[i])
  }
  result.push(variance(tail))
  result
}

///|
pub fn boundary_quality(
  values : Array[Double],
  boundary : Int,
  minimum_segment? : Int = 3,
) -> Double {
  let safe = if minimum_segment < 1 { 1 } else { minimum_segment }
  if boundary < safe || values.length() - boundary < safe {
    return 0.0
  }
  let left : Array[Double] = []
  let right : Array[Double] = []
  for i in 0..<boundary {
    left.push(values[i])
  }
  for i in boundary..<values.length() {
    right.push(values[i])
  }
  let shift = mean_shift_score(values, boundary, min_segment=safe)
  let quality = (segment_quality(left).score + segment_quality(right).score) /
    2.0
  shift * quality
}

///|
pub fn best_boundary(values : Array[Double], minimum_segment? : Int = 3) -> Int {
  let safe = if minimum_segment < 1 { 1 } else { minimum_segment }
  if values.length() < safe * 2 {
    return -1
  }
  let mut best = safe
  let mut best_score = boundary_quality(values, safe, minimum_segment=safe)
  for boundary in safe..<(values.length() - safe + 1) {
    let score = boundary_quality(values, boundary, minimum_segment=safe)
    if score > best_score {
      best = boundary
      best_score = score
    }
  }
  best
}

///|
pub fn segment_profile(
  values : Array[Double],
  boundaries : Array[Int],
) -> Array[StatsSummary] {
  let result : Array[StatsSummary] = []
  let mut start = 0
  for boundary in boundaries {
    let end = if boundary > values.length() {
      values.length()
    } else if boundary < start {
      start
    } else {
      boundary
    }
    let part : Array[Double] = []
    for i in start..<end {
      part.push(values[i])
    }
    let accumulator = OnlineMoments::new()
    for value in part {
      accumulator.push(value)
    }
    result.push(accumulator.summary(median=median(part)))
    start = end
  }
  let tail : Array[Double] = []
  for i in start..<values.length() {
    tail.push(values[i])
  }
  let accumulator = OnlineMoments::new()
  for value in tail {
    accumulator.push(value)
  }
  result.push(accumulator.summary(median=median(tail)))
  result
}

///|
pub fn quality_gate(
  values : Array[Double],
  minimum_score? : Double = 0.5,
) -> Bool {
  segment_quality(values).score >= clamp_probability(minimum_score)
}
