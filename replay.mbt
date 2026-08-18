///|
/// Deterministic replay utilities for incident investigation and regression tests.
pub struct ReplayRecord {
  point : SignalPoint
  result : DetectionResult
  elapsed : Int64
}

///|
pub fn ReplayRecord::new(
  point : SignalPoint,
  result : DetectionResult,
  elapsed : Int64,
) -> ReplayRecord {
  { point, result, elapsed }
}

///|
pub struct ReplaySummary {
  total : Int
  changed : Int
  first_change : Int
  last_change : Int
  mean_score : Double
  max_score : Double
  elapsed : Int64
}

///|
pub fn ReplaySummary::empty() -> ReplaySummary {
  {
    total: 0,
    changed: 0,
    first_change: -1,
    last_change: -1,
    mean_score: 0.0,
    max_score: 0.0,
    elapsed: 0L,
  }
}

///|
pub fn summarize_replay(records : Array[ReplayRecord]) -> ReplaySummary {
  if records.length() == 0 {
    return ReplaySummary::empty()
  }
  let mut changed = 0
  let mut first = -1
  let mut last = -1
  let mut total_score = 0.0
  let mut maximum = 0.0
  let mut elapsed = 0L
  for record in records {
    total_score += record.result.score
    if record.result.score > maximum {
      maximum = record.result.score
    }
    elapsed += record.elapsed
    if record.result.changed {
      if first < 0 {
        first = record.result.index
      }
      last = record.result.index
      changed += 1
    }
  }
  {
    total: records.length(),
    changed,
    first_change: first,
    last_change: last,
    mean_score: total_score / records.length().to_double(),
    max_score: maximum,
    elapsed,
  }
}

///|
pub fn replay_checksum(records : Array[ReplayRecord]) -> Double {
  let mut checksum = 0.0
  for i, record in records {
    checksum += (i + 1).to_double() * (record.point.value + record.result.score)
  }
  checksum
}

///|
pub fn replay_values(records : Array[ReplayRecord]) -> Array[Double] {
  let result : Array[Double] = []
  for record in records {
    result.push(record.point.value)
  }
  result
}

///|
pub fn replay_changed_indices(records : Array[ReplayRecord]) -> Array[Int] {
  let result : Array[Int] = []
  for record in records {
    if record.result.changed {
      result.push(record.result.index)
    }
  }
  result
}

///|
pub fn replay_window(
  records : Array[ReplayRecord],
  start : Int,
  end : Int,
) -> Array[ReplayRecord] {
  let result : Array[ReplayRecord] = []
  let low = if start < 0 { 0 } else { start }
  let high = if end > records.length() { records.length() } else { end }
  if low >= high {
    return result
  }
  for i in low..<high {
    result.push(records[i])
  }
  result
}

///|
pub fn replay_latency_percentile(
  records : Array[ReplayRecord],
  probability : Double,
) -> Int64 {
  let elapsed : Array[Double] = []
  for record in records {
    elapsed.push(record.elapsed.to_double())
  }
  quantile(elapsed, probability).to_int64()
}

///|
pub fn replay_summary_markdown(summary : ReplaySummary) -> String {
  "| total | changed | first | last | mean score | max score | elapsed |\n|---:|---:|---:|---:|---:|---:|---:|\n| \{summary.total} | \{summary.changed} | \{summary.first_change} | \{summary.last_change} | \{summary.mean_score} | \{summary.max_score} | \{summary.elapsed} |"
}

///|
pub struct ReplayComparator {
  score_tolerance : Double
  confidence_tolerance : Double
  mut compared : Int
  mut mismatches : Int
}

///|
pub fn ReplayComparator::new(
  score_tolerance? : Double = 0.000000001,
  confidence_tolerance? : Double = 0.000000001,
) -> ReplayComparator {
  {
    score_tolerance: if score_tolerance < 0.0 {
      0.0
    } else {
      score_tolerance
    },
    confidence_tolerance: if confidence_tolerance < 0.0 {
      0.0
    } else {
      confidence_tolerance
    },
    compared: 0,
    mismatches: 0,
  }
}

///|
pub fn ReplayComparator::compare(
  self : ReplayComparator,
  expected : DetectionResult,
  actual : DetectionResult,
) -> Bool {
  self.compared += 1
  let same = expected.changed == actual.changed &&
    absolute(expected.score - actual.score) <= self.score_tolerance &&
    absolute(expected.confidence - actual.confidence) <=
    self.confidence_tolerance &&
    expected.index == actual.index
  if !same {
    self.mismatches += 1
  }
  same
}

///|
pub fn ReplayComparator::compared(self : ReplayComparator) -> Int {
  self.compared
}

///|
pub fn ReplayComparator::mismatches(self : ReplayComparator) -> Int {
  self.mismatches
}
