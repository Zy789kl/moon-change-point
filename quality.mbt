///|
pub(all) enum QualityIssue {
  MissingValue
  NonFiniteValue
  OutOfRange
  NonMonotonicTimestamp
  ExcessiveGap
  DimensionMismatch
}

///|
pub struct QualityReport {
  mut count : Int
  mut valid : Int
  missing : Int
  mut non_finite : Int
  mut out_of_range : Int
  mut non_monotonic : Int
  mut excessive_gaps : Int
  issues : Array[QualityIssue]
}

///|
pub fn QualityReport::empty() -> QualityReport {
  {
    count: 0,
    valid: 0,
    missing: 0,
    non_finite: 0,
    out_of_range: 0,
    non_monotonic: 0,
    excessive_gaps: 0,
    issues: [],
  }
}

///|
pub fn QualityReport::is_healthy(self : QualityReport) -> Bool {
  self.missing == 0 &&
  self.non_finite == 0 &&
  self.out_of_range == 0 &&
  self.non_monotonic == 0 &&
  self.excessive_gaps == 0
}

///|
pub fn QualityReport::valid_ratio(self : QualityReport) -> Double {
  if self.count == 0 {
    1.0
  } else {
    self.valid.to_double() / self.count.to_double()
  }
}

///|
pub fn validate_values(
  values : Array[Double],
  lower? : Double? = None,
  upper? : Double? = None,
) -> QualityReport {
  let report = QualityReport::empty()
  report.count = values.length()
  for value in values {
    if !is_finite(value) {
      report.non_finite += 1
      ignore(report.issues.push(NonFiniteValue))
    } else {
      let lower_ok = match lower {
        None => true
        Some(low) => value >= low
      }
      let upper_ok = match upper {
        None => true
        Some(high) => value <= high
      }
      if lower_ok && upper_ok {
        report.valid += 1
      } else {
        report.out_of_range += 1
        ignore(report.issues.push(OutOfRange))
      }
    }
  }
  report
}

///|
pub fn validate_points(
  points : Array[SignalPoint],
  maximum_gap? : Int64? = None,
) -> QualityReport {
  let report = QualityReport::empty()
  report.count = points.length()
  let mut previous : Int64? = None
  for point in points {
    if !is_finite(point.value) {
      report.non_finite += 1
      ignore(report.issues.push(NonFiniteValue))
    } else {
      report.valid += 1
    }
    match previous {
      None => ()
      Some(timestamp) => {
        if point.timestamp <= timestamp {
          report.non_monotonic += 1
          ignore(report.issues.push(NonMonotonicTimestamp))
        }
        match maximum_gap {
          None => ()
          Some(gap) =>
            if point.timestamp - timestamp > gap {
              report.excessive_gaps += 1
              ignore(report.issues.push(ExcessiveGap))
            }
        }
      }
    }
    previous = Some(point.timestamp)
  }
  report
}

///|
pub fn remove_invalid(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  for value in values {
    if is_finite(value) {
      result.push(value)
    }
  }
  result
}

///|
pub fn replace_invalid(
  values : Array[Double],
  replacement? : Double = 0.0,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in values {
    result.push(if is_finite(value) { value } else { replacement })
  }
  result
}

///|
pub fn quality_score(report : QualityReport) -> Double {
  if report.count == 0 {
    return 1.0
  }
  let total_issues = report.missing +
    report.non_finite +
    report.out_of_range +
    report.non_monotonic +
    report.excessive_gaps
  clamp_probability(1.0 - total_issues.to_double() / report.count.to_double())
}

///|
pub struct DataQualityGate {
  minimum_ratio : Double
  reject_non_monotonic : Bool
  reject_dimension_mismatch : Bool
}

///|
pub fn DataQualityGate::new(
  minimum_ratio? : Double = 0.95,
  reject_non_monotonic? : Bool = true,
  reject_dimension_mismatch? : Bool = true,
) -> DataQualityGate {
  {
    minimum_ratio: clamp_probability(minimum_ratio),
    reject_non_monotonic,
    reject_dimension_mismatch,
  }
}

///|
pub fn DataQualityGate::accept(
  self : DataQualityGate,
  report : QualityReport,
) -> Bool {
  quality_score(report) >= self.minimum_ratio &&
  (!self.reject_non_monotonic || report.non_monotonic == 0)
}

///|
pub fn contiguous_ranges(
  points : Array[SignalPoint],
  maximum_gap : Int64,
) -> Array[SegmentRange] {
  let result : Array[SegmentRange] = []
  if points.length() == 0 {
    return result
  }
  let mut start = 0
  for i in 1..<points.length() {
    if points[i].timestamp - points[i - 1].timestamp > maximum_gap {
      result.push({ start, end: i })
      start = i
    }
  }
  result.push({ start, end: points.length() })
  result
}
