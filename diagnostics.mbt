///|
/// Diagnostic comparison between two adjacent windows.
pub struct WindowDiagnostic {
  before : StatsSummary
  after : StatsSummary
  mean_shift : Double
  variance_ratio : Double
  distribution_shift : Double
  severity : AlertSeverity
  actionable : Bool
}

///|
pub fn WindowDiagnostic::empty() -> WindowDiagnostic {
  {
    before: StatsSummary::empty(),
    after: StatsSummary::empty(),
    mean_shift: 0.0,
    variance_ratio: 1.0,
    distribution_shift: 0.0,
    severity: Informational,
    actionable: false,
  }
}

///|
pub fn diagnose_windows(
  before_values : Array[Double],
  after_values : Array[Double],
  shift_threshold? : Double = 0.5,
  distribution_threshold? : Double = 0.25,
) -> WindowDiagnostic {
  let before_accumulator = OnlineMoments::new()
  for value in before_values {
    before_accumulator.push(value)
  }
  let after_accumulator = OnlineMoments::new()
  for value in after_values {
    after_accumulator.push(value)
  }
  let before = before_accumulator.summary(median=median(before_values))
  let after = after_accumulator.summary(median=median(after_values))
  let shift = absolute(after.mean - before.mean)
  let ratio = if before.variance <= 1.0e-12 {
    if after.variance > 0.0 {
      1.7976931348623157e308
    } else {
      1.0
    }
  } else {
    after.variance / before.variance
  }
  let distribution = ks_statistic(before_values, after_values)
  let score = clamp_probability(shift / (shift + 1.0) + distribution / 2.0)
  let severity = severity_from_score(score)
  {
    before,
    after,
    mean_shift: shift,
    variance_ratio: ratio,
    distribution_shift: distribution,
    severity,
    actionable: shift >= shift_threshold ||
    distribution >= distribution_threshold,
  }
}

///|
pub fn diagnostic_score(diagnostic : WindowDiagnostic) -> Double {
  let variance_score = if diagnostic.variance_ratio >= 1.0 {
    1.0 - 1.0 / diagnostic.variance_ratio
  } else {
    1.0 - diagnostic.variance_ratio
  }
  clamp_probability(
    diagnostic.mean_shift / (diagnostic.mean_shift + 1.0) * 0.5 +
    diagnostic.distribution_shift * 0.3 +
    variance_score * 0.2,
  )
}

///|
pub fn diagnostic_direction(diagnostic : WindowDiagnostic) -> ChangeDirection {
  if diagnostic.mean_shift > 0.0 {
    if diagnostic.after.mean > diagnostic.before.mean {
      Increase
    } else {
      Decrease
    }
  } else if diagnostic.variance_ratio > 1.0 {
    VarianceIncrease
  } else if diagnostic.variance_ratio < 1.0 {
    VarianceDecrease
  } else {
    Unknown
  }
}

///|
pub fn diagnostic_label(diagnostic : WindowDiagnostic) -> String {
  severity_name(diagnostic.severity) +
  ":" +
  direction_name(diagnostic_direction(diagnostic))
}

///|
pub fn diagnostic_markdown(diagnostic : WindowDiagnostic) -> String {
  "| field | value |\n|---|---:|\n| before mean | \{diagnostic.before.mean} |\n| after mean | \{diagnostic.after.mean} |\n| mean shift | \{diagnostic.mean_shift} |\n| variance ratio | \{diagnostic.variance_ratio} |\n| distribution shift | \{diagnostic.distribution_shift} |\n| severity | \{severity_name(diagnostic.severity)} |"
}

///|
pub fn diagnose_series(
  values : Array[Double],
  split : Int,
  minimum_segment? : Int = 3,
) -> WindowDiagnostic {
  let safe_split = if split < 0 {
    0
  } else if split > values.length() {
    values.length()
  } else {
    split
  }
  let before : Array[Double] = []
  let after : Array[Double] = []
  for i in 0..<safe_split {
    before.push(values[i])
  }
  for i in safe_split..<values.length() {
    after.push(values[i])
  }
  diagnose_windows(
    before,
    after,
    shift_threshold=mean_shift_score(
      values,
      safe_split,
      min_segment=minimum_segment,
    ),
  )
}

///|
pub fn diagnostics_batch(
  values : Array[Double],
  splits : Array[Int],
) -> Array[WindowDiagnostic] {
  let result : Array[WindowDiagnostic] = []
  for split in splits {
    result.push(diagnose_series(values, split))
  }
  result
}

///|
pub fn actionable_diagnostics(diagnostics : Array[WindowDiagnostic]) -> Int {
  let mut count = 0
  for diagnostic in diagnostics {
    if diagnostic.actionable {
      count += 1
    }
  }
  count
}
