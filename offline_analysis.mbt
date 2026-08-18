///|
/// A candidate change point returned by offline analysis.
pub struct OfflineChange {
  index : Int
  score : Double
  left_mean : Double
  right_mean : Double
  left_variance : Double
  right_variance : Double
  direction : ChangeDirection
}

///|
/// A half-open segment used by dynamic programming and binary segmentation.
pub struct SegmentRange {
  start : Int
  end : Int
}

///|
pub fn SegmentRange::new(start : Int, end : Int) -> SegmentRange {
  { start, end }
}

///|
pub fn SegmentRange::length(self : SegmentRange) -> Int {
  self.end - self.start
}

///|
fn slice_values(
  values : Array[Double],
  start : Int,
  end : Int,
) -> Array[Double] {
  let safe_start = if start < 0 { 0 } else { start }
  let safe_end = if end > values.length() { values.length() } else { end }
  let result : Array[Double] = []
  if safe_start >= safe_end {
    return result
  }
  for i in safe_start..<safe_end {
    result.push(values[i])
  }
  result
}

///|
fn segment_mean(values : Array[Double], start : Int, end : Int) -> Double {
  mean(slice_values(values, start, end))
}

///|
fn segment_variance(values : Array[Double], start : Int, end : Int) -> Double {
  variance(slice_values(values, start, end))
}

///|
/// Standardized mean difference between two adjacent segments.
pub fn mean_shift_score(
  values : Array[Double],
  split : Int,
  min_segment? : Int = 3,
) -> Double {
  let minimum = if min_segment < 1 { 1 } else { min_segment }
  if split < minimum || values.length() - split < minimum {
    return 0.0
  }
  let left_mean = segment_mean(values, 0, split)
  let right_mean = segment_mean(values, split, values.length())
  let left_variance = segment_variance(values, 0, split)
  let right_variance = segment_variance(values, split, values.length())
  let pooled = (
      (split - 1).to_double() * left_variance +
      (values.length() - split - 1).to_double() * right_variance
    ) /
    (values.length() - 2).to_double()
  let scale = if pooled <= 1.0e-12 { 1.0e-6 } else { pooled.sqrt() }
  absolute(left_mean - right_mean) / scale
}

///|
/// Returns a change record for a split, or None when the split is outside the valid range.
pub fn inspect_split(
  values : Array[Double],
  split : Int,
  min_segment? : Int = 3,
) -> OfflineChange? {
  let minimum = if min_segment < 1 { 1 } else { min_segment }
  if split < minimum || values.length() - split < minimum {
    return None
  }
  let left_mean = segment_mean(values, 0, split)
  let right_mean = segment_mean(values, split, values.length())
  let left_variance = segment_variance(values, 0, split)
  let right_variance = segment_variance(values, split, values.length())
  let score = mean_shift_score(values, split, min_segment=minimum)
  let direction = if right_mean > left_mean {
    Increase
  } else if right_mean < left_mean {
    Decrease
  } else if right_variance > left_variance {
    VarianceIncrease
  } else {
    VarianceDecrease
  }
  Some({
    index: split,
    score,
    left_mean,
    right_mean,
    left_variance,
    right_variance,
    direction,
  })
}

///|
/// Scans every valid split and returns a score for each index.
pub fn window_change_scores(
  values : Array[Double],
  min_segment? : Int = 3,
) -> Array[Double] {
  let scores = Array::make(values.length(), 0.0)
  let minimum = if min_segment < 1 { 1 } else { min_segment }
  if values.length() < minimum * 2 {
    return scores
  }
  for split in minimum..<(values.length() - minimum + 1) {
    scores[split] = mean_shift_score(values, split, min_segment=minimum)
  }
  scores
}

///|
fn best_split_in_range(
  values : Array[Double],
  range : SegmentRange,
  min_segment : Int,
) -> OfflineChange? {
  let safe_minimum = if min_segment < 1 { 1 } else { min_segment }
  if range.length() < safe_minimum * 2 {
    return None
  }
  let mut best : OfflineChange? = None
  for split in (range.start + safe_minimum)..<(range.end - safe_minimum + 1) {
    let candidate = inspect_split(
      slice_values(values, range.start, range.end),
      split - range.start,
      min_segment=safe_minimum,
    )
    match candidate {
      None => ()
      Some(change) => {
        let adjusted = {
          index: split,
          score: change.score,
          left_mean: change.left_mean,
          right_mean: change.right_mean,
          left_variance: change.left_variance,
          right_variance: change.right_variance,
          direction: change.direction,
        }
        match best {
          None => best = Some(adjusted)
          Some(previous) =>
            if adjusted.score > previous.score {
              best = Some(adjusted)
            }
        }
      }
    }
  }
  best
}

///|
/// Greedy binary segmentation for a small number of interpretable changes.
pub fn binary_segmentation(
  values : Array[Double],
  threshold? : Double = 3.0,
  min_segment? : Int = 5,
  max_changes? : Int = 8,
) -> Array[OfflineChange] {
  let result : Array[OfflineChange] = []
  let pending : Array[SegmentRange] = [{ start: 0, end: values.length() }]
  let minimum = if min_segment < 1 { 1 } else { min_segment }
  let limit = if max_changes < 0 { 0 } else { max_changes }
  let cutoff = if threshold < 0.0 { 0.0 } else { threshold }
  while pending.length() > 0 && result.length() < limit {
    let range = pending.remove(0)
    match best_split_in_range(values, range, minimum) {
      None => ()
      Some(change) =>
        if change.score >= cutoff {
          let mut position = result.length()
          for i in 0..<result.length() {
            if change.index < result[i].index {
              position = i
              break
            }
          }
          result.push(change)
          let mut i = result.length() - 1
          while i > position {
            result[i] = result[i - 1]
            i -= 1
          }
          result[position] = change
          pending.push({ start: range.start, end: change.index })
          pending.push({ start: change.index, end: range.end })
        }
    }
  }
  result
}

///|
fn segment_cost(values : Array[Double], start : Int, end : Int) -> Double {
  let sample = slice_values(values, start, end)
  let center = mean(sample)
  let mut cost = 0.0
  for value in sample {
    let delta = value - center
    cost += delta * delta
  }
  cost
}

///|
/// Penalized dynamic programming for minimum-description-length style segmentation.
pub fn optimal_changepoints(
  values : Array[Double],
  penalty? : Double = 3.0,
  min_segment? : Int = 3,
  max_changes? : Int = 8,
) -> Array[Int] {
  let n = values.length()
  let minimum = if min_segment < 1 { 1 } else { min_segment }
  let limit = if max_changes < 0 { 0 } else { max_changes }
  let costs = Array::make(n + 1, 0.0)
  let previous = Array::make(n + 1, -1)
  for end in 1..<=n {
    costs[end] = segment_cost(values, 0, end)
    if end >= minimum {
      for start in minimum..<(end - minimum + 1) {
        let candidate = costs[start] +
          segment_cost(values, start, end) +
          penalty
        if candidate < costs[end] {
          costs[end] = candidate
          previous[end] = start
        }
      }
    }
  }
  let result : Array[Int] = []
  let mut cursor = n
  while cursor > 0 && result.length() < limit {
    let split = previous[cursor]
    if split <= 0 {
      break
    }
    result.push(split)
    cursor = split
  }
  let mut left = 0
  let mut right = result.length() - 1
  while left < right {
    let value = result[left]
    result[left] = result[right]
    result[right] = value
    left += 1
    right -= 1
  }
  result
}

///|
/// Removes candidates closer than `minimum_distance`, preserving the highest score.
pub fn merge_nearby_changes(
  changes : Array[OfflineChange],
  minimum_distance : Int,
) -> Array[OfflineChange] {
  let sorted : Array[OfflineChange] = []
  for change in changes {
    let mut position = sorted.length()
    for i in 0..<sorted.length() {
      if change.index < sorted[i].index {
        position = i
        break
      }
    }
    sorted.push(change)
    let mut i = sorted.length() - 1
    while i > position {
      sorted[i] = sorted[i - 1]
      i -= 1
    }
    sorted[position] = change
  }
  let result : Array[OfflineChange] = []
  let distance = if minimum_distance < 1 { 1 } else { minimum_distance }
  for change in sorted {
    if result.length() == 0 {
      result.push(change)
    } else {
      let last = result[result.length() - 1]
      if change.index - last.index < distance {
        if change.score > last.score {
          result[result.length() - 1] = change
        }
      } else {
        result.push(change)
      }
    }
  }
  result
}

///|
/// Quality metrics for a set of predicted change indices.
pub struct ChangePointMetrics {
  true_positives : Int
  false_positives : Int
  false_negatives : Int
  precision : Double
  recall : Double
  f1 : Double
  mean_detection_delay : Double
}

///|
pub fn ChangePointMetrics::empty() -> ChangePointMetrics {
  {
    true_positives: 0,
    false_positives: 0,
    false_negatives: 0,
    precision: 0.0,
    recall: 0.0,
    f1: 0.0,
    mean_detection_delay: 0.0,
  }
}

///|
/// Matches a prediction to at most one truth within a tolerance window.
pub fn evaluate_change_points(
  predicted : Array[Int],
  truth : Array[Int],
  tolerance? : Int = 3,
) -> ChangePointMetrics {
  if truth.length() == 0 {
    return {
      true_positives: 0,
      false_positives: predicted.length(),
      false_negatives: 0,
      precision: if predicted.length() == 0 {
        1.0
      } else {
        0.0
      },
      recall: 1.0,
      f1: if predicted.length() == 0 {
        1.0
      } else {
        0.0
      },
      mean_detection_delay: 0.0,
    }
  }
  let matched = Array::make(truth.length(), false)
  let mut true_positives = 0
  let mut false_positives = 0
  let mut delay = 0.0
  let window = if tolerance < 0 { 0 } else { tolerance }
  for prediction in predicted {
    let mut match_index = -1
    let mut best_distance = 2147483647
    for i in 0..<truth.length() {
      let distance = absolute((prediction - truth[i]).to_double()).to_int()
      if !matched[i] && distance <= window && distance < best_distance {
        match_index = i
        best_distance = distance
      }
    }
    if match_index >= 0 {
      matched[match_index] = true
      true_positives += 1
      delay += absolute((prediction - truth[match_index]).to_double())
    } else {
      false_positives += 1
    }
  }
  let false_negatives = truth.length() - true_positives
  let precision = if true_positives + false_positives == 0 {
    0.0
  } else {
    true_positives.to_double() / (true_positives + false_positives).to_double()
  }
  let recall = true_positives.to_double() / truth.length().to_double()
  let f1 = if precision + recall == 0.0 {
    0.0
  } else {
    2.0 * precision * recall / (precision + recall)
  }
  {
    true_positives,
    false_positives,
    false_negatives,
    precision,
    recall,
    f1,
    mean_detection_delay: if true_positives == 0 {
      0.0
    } else {
      delay / true_positives.to_double()
    },
  }
}

///|
/// Computes a reconstruction error when each segment is represented by its mean.
pub fn piecewise_constant_error(
  values : Array[Double],
  changes : Array[Int],
) -> Double {
  let boundaries : Array[Int] = [0]
  for change in changes {
    if change > 0 && change < values.length() {
      boundaries.push(change)
    }
  }
  boundaries.push(values.length())
  let mut total = 0.0
  for i in 0..<(boundaries.length() - 1) {
    total += segment_cost(values, boundaries[i], boundaries[i + 1])
  }
  total
}
