///|
/// The direction of a distributional change.
pub(all) enum ChangeDirection {
  Increase
  Decrease
  VarianceIncrease
  VarianceDecrease
  DistributionShift
  Unknown
}

///|
/// The severity used by alerting integrations.
pub(all) enum AlertSeverity {
  Informational
  Warning
  Critical
}

///|
/// A normalized result returned by online and offline detectors.
pub struct DetectionResult {
  changed : Bool
  score : Double
  confidence : Double
  direction : ChangeDirection
  index : Int
  evidence : Double
}

///|
/// Builds a result while keeping confidence and evidence in a safe range.
pub fn DetectionResult::new(
  changed : Bool,
  score : Double,
  confidence : Double,
  direction : ChangeDirection,
  index : Int,
  evidence? : Double = 0.0,
) -> DetectionResult {
  let safe_confidence = clamp_probability(confidence)
  let safe_score = if !is_finite(score) || score < 0.0 { 0.0 } else { score }
  {
    changed,
    score: safe_score,
    confidence: safe_confidence,
    direction,
    index,
    evidence,
  }
}

///|
/// Returns a result that represents an ordinary observation.
pub fn DetectionResult::quiet(index? : Int = 0) -> DetectionResult {
  DetectionResult::new(false, 0.0, 0.0, Unknown, index)
}

///|
/// Converts a score into a stable three-level severity.
pub fn severity_from_score(score : Double) -> AlertSeverity {
  if score >= 0.9 {
    Critical
  } else if score >= 0.6 {
    Warning
  } else {
    Informational
  }
}

///|
/// Returns a human-readable direction label.
pub fn direction_name(direction : ChangeDirection) -> String {
  match direction {
    Increase => "increase"
    Decrease => "decrease"
    VarianceIncrease => "variance-increase"
    VarianceDecrease => "variance-decrease"
    DistributionShift => "distribution-shift"
    Unknown => "unknown"
  }
}

///|
/// Returns a human-readable severity label.
pub fn severity_name(severity : AlertSeverity) -> String {
  match severity {
    Informational => "informational"
    Warning => "warning"
    Critical => "critical"
  }
}

///|
/// Produces a compact representation suitable for logs.
pub fn DetectionResult::summary(self : DetectionResult) -> String {
  "changed=\{self.changed},score=\{self.score},confidence=\{self.confidence},direction=\{direction_name(self.direction)},index=\{self.index}"
}

///|
/// A point in a time series. Timestamps are integer ticks supplied by the caller.
pub struct SignalPoint {
  timestamp : Int64
  value : Double
  sequence : Int
}

///|
/// Creates a signal point.
pub fn SignalPoint::new(
  timestamp : Int64,
  value : Double,
  sequence? : Int = 0,
) -> SignalPoint {
  { timestamp, value, sequence }
}

///|
/// A detected change with enough context for a downstream alert or dashboard.
pub struct ChangePoint {
  timestamp : Int64
  index : Int
  score : Double
  confidence : Double
  severity : AlertSeverity
  direction : ChangeDirection
  detector : String
  baseline : Double
  observed : Double
}

///|
/// Creates a change point from an online result.
pub fn ChangePoint::from_result(
  point : SignalPoint,
  result : DetectionResult,
  detector : String,
  baseline : Double,
) -> ChangePoint {
  {
    timestamp: point.timestamp,
    index: result.index,
    score: result.score,
    confidence: result.confidence,
    severity: severity_from_score(result.score),
    direction: result.direction,
    detector,
    baseline,
    observed: point.value,
  }
}

///|
/// Returns a stable log line for a change point.
pub fn ChangePoint::summary(self : ChangePoint) -> String {
  "\{self.detector}@\{self.timestamp}: \{direction_name(self.direction)} score=\{self.score} confidence=\{self.confidence} severity=\{severity_name(self.severity)}"
}

///|
/// A compact summary of a numeric sample.
pub struct StatsSummary {
  count : Int
  mean : Double
  variance : Double
  standard_deviation : Double
  minimum : Double
  maximum : Double
  median : Double
  first : Double
  last : Double
}

///|
/// Creates an empty summary.
pub fn StatsSummary::empty() -> StatsSummary {
  {
    count: 0,
    mean: 0.0,
    variance: 0.0,
    standard_deviation: 0.0,
    minimum: 0.0,
    maximum: 0.0,
    median: 0.0,
    first: 0.0,
    last: 0.0,
  }
}

///|
/// A named alert emitted by a multi-series pipeline.
pub struct AlertEvent {
  metric : String
  point : ChangePoint
  suppressed : Bool
  ordinal : Int
}

///|
/// Constructs an alert event.
pub fn AlertEvent::new(
  metric : String,
  point : ChangePoint,
  suppressed? : Bool = false,
  ordinal? : Int = 0,
) -> AlertEvent {
  { metric, point, suppressed, ordinal }
}

///|
/// Clamps a probability-like number to the closed unit interval.
pub fn clamp_probability(value : Double) -> Double {
  if value != value {
    0.0
  } else if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// Returns the absolute value without exposing math implementation details.
pub fn absolute(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
/// Returns the sign of a number.
pub fn sign(value : Double) -> Int {
  if value > 0.0 {
    1
  } else if value < 0.0 {
    -1
  } else {
    0
  }
}

///|
/// Returns whether a value is finite enough for detector state.
pub fn is_finite(value : Double) -> Bool {
  value == value &&
  value < 1.7976931348623157e308 &&
  value > -1.7976931348623157e308
}
