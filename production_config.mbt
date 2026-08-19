///|
/// Operating mode for a production monitor.
pub(all) enum ProductionMonitorMode {
  ObserveOnly
  Alerting
  Backfill
  Replay
}

///|
/// Strategy used when an input value is not usable.
pub(all) enum MissingValueStrategy {
  DropValue
  ImputeLast
  ImputeMean
  ImputeZero
  MarkUnknown
}

///|
/// Strategy used to establish a detector baseline.
pub(all) enum ProductionBaselineStrategy {
  FixedBaseline
  RollingMedian
  RollingMean
  ExponentiallyWeighted
  SeasonalBaseline
}

///|
/// Action taken after a detector has reached a stable state.
pub(all) enum RecoveryAction {
  KeepOpen
  AutoResolve
  RequireAcknowledgement
  Escalate
}

///|
/// A single issue found while validating production configuration.
pub struct ProductionConfigIssue {
  field : String
  message : String
  fatal : Bool
}

///|
pub fn ProductionConfigIssue::new(
  field : String,
  message : String,
  fatal? : Bool = true,
) -> ProductionConfigIssue {
  { field, message, fatal }
}

///|
pub fn ProductionConfigIssue::field(self : ProductionConfigIssue) -> String {
  self.field
}

///|
pub fn ProductionConfigIssue::message(self : ProductionConfigIssue) -> String {
  self.message
}

///|
pub fn ProductionConfigIssue::fatal(self : ProductionConfigIssue) -> Bool {
  self.fatal
}

///|
pub fn ProductionConfigIssue::summary(self : ProductionConfigIssue) -> String {
  let severity = if self.fatal { "error" } else { "warning" }
  severity + ":" + self.field + ":" + self.message
}

///|
/// Detection settings shared by online monitor instances.
pub struct ProductionDetectionConfig {
  detector_name : String
  threshold : Double
  confidence : Double
  warmup_points : Int
  minimum_segment : Int
  maximum_score : Double
  direction_filter : ChangeDirection?
}

///|
pub fn ProductionDetectionConfig::new(
  detector_name? : String = "cusum",
  threshold? : Double = 1.0,
  confidence? : Double = 0.5,
  warmup_points? : Int = 16,
  minimum_segment? : Int = 3,
  maximum_score? : Double = 1.0e6,
  direction_filter? : ChangeDirection? = None,
) -> ProductionDetectionConfig {
  {
    detector_name,
    threshold: if threshold < 0.0 {
      0.0
    } else {
      threshold
    },
    confidence: clamp_probability(confidence),
    warmup_points: if warmup_points < 1 {
      1
    } else {
      warmup_points
    },
    minimum_segment: if minimum_segment < 1 {
      1
    } else {
      minimum_segment
    },
    maximum_score: if maximum_score <= 0.0 {
      1.0e6
    } else {
      maximum_score
    },
    direction_filter,
  }
}

///|
pub fn ProductionDetectionConfig::detector_name(
  self : ProductionDetectionConfig,
) -> String {
  self.detector_name
}

///|
pub fn ProductionDetectionConfig::threshold(
  self : ProductionDetectionConfig,
) -> Double {
  self.threshold
}

///|
pub fn ProductionDetectionConfig::confidence(
  self : ProductionDetectionConfig,
) -> Double {
  self.confidence
}

///|
pub fn ProductionDetectionConfig::warmup_points(
  self : ProductionDetectionConfig,
) -> Int {
  self.warmup_points
}

///|
pub fn ProductionDetectionConfig::minimum_segment(
  self : ProductionDetectionConfig,
) -> Int {
  self.minimum_segment
}

///|
pub fn ProductionDetectionConfig::maximum_score(
  self : ProductionDetectionConfig,
) -> Double {
  self.maximum_score
}

///|
pub fn ProductionDetectionConfig::direction_filter(
  self : ProductionDetectionConfig,
) -> ChangeDirection? {
  self.direction_filter
}

///|
pub fn ProductionDetectionConfig::accepts(
  self : ProductionDetectionConfig,
  result : DetectionResult,
) -> Bool {
  let direction_ok = match self.direction_filter {
    None => true
    Some(direction) => production_directions_match(direction, result.direction)
  }
  result.changed &&
  result.score >= self.threshold &&
  result.score <= self.maximum_score &&
  result.confidence >= self.confidence &&
  direction_ok
}

///|
/// Event-time and memory settings for an operational stream.
pub struct ProductionWindowConfig {
  reorder_capacity : Int
  allowed_lateness : Int64
  aggregate_size : Int
  retention_points : Int
  maximum_gap : Int64?
  deduplicate_timestamps : Bool
}

///|
pub fn ProductionWindowConfig::new(
  reorder_capacity? : Int = 64,
  allowed_lateness? : Int64 = 5L,
  aggregate_size? : Int = 1,
  retention_points? : Int = 1024,
  maximum_gap? : Int64? = None,
  deduplicate_timestamps? : Bool = true,
) -> ProductionWindowConfig {
  {
    reorder_capacity: if reorder_capacity < 1 {
      1
    } else {
      reorder_capacity
    },
    allowed_lateness: if allowed_lateness < 0L {
      0L
    } else {
      allowed_lateness
    },
    aggregate_size: if aggregate_size < 1 {
      1
    } else {
      aggregate_size
    },
    retention_points: if retention_points < 1 {
      1
    } else {
      retention_points
    },
    maximum_gap,
    deduplicate_timestamps,
  }
}

///|
pub fn ProductionWindowConfig::reorder_capacity(
  self : ProductionWindowConfig,
) -> Int {
  self.reorder_capacity
}

///|
pub fn ProductionWindowConfig::allowed_lateness(
  self : ProductionWindowConfig,
) -> Int64 {
  self.allowed_lateness
}

///|
pub fn ProductionWindowConfig::aggregate_size(
  self : ProductionWindowConfig,
) -> Int {
  self.aggregate_size
}

///|
pub fn ProductionWindowConfig::retention_points(
  self : ProductionWindowConfig,
) -> Int {
  self.retention_points
}

///|
pub fn ProductionWindowConfig::maximum_gap(
  self : ProductionWindowConfig,
) -> Int64? {
  self.maximum_gap
}

///|
pub fn ProductionWindowConfig::deduplicate_timestamps(
  self : ProductionWindowConfig,
) -> Bool {
  self.deduplicate_timestamps
}

///|
/// Alert and recovery settings for a monitored metric.
pub struct ProductionAlertConfig {
  minimum_score : Double
  minimum_confidence : Double
  minimum_gap : Int64
  recovery_points : Int
  action : RecoveryAction
  severity : AlertSeverity
  budget_per_window : Int
  budget_window : Int64
}

///|
pub fn ProductionAlertConfig::new(
  minimum_score? : Double = 1.0,
  minimum_confidence? : Double = 0.5,
  minimum_gap? : Int64 = 5L,
  recovery_points? : Int = 3,
  action? : RecoveryAction = AutoResolve,
  severity? : AlertSeverity = Warning,
  budget_per_window? : Int = 20,
  budget_window? : Int64 = 60L,
) -> ProductionAlertConfig {
  {
    minimum_score: if minimum_score < 0.0 {
      0.0
    } else {
      minimum_score
    },
    minimum_confidence: clamp_probability(minimum_confidence),
    minimum_gap: if minimum_gap < 0L {
      0L
    } else {
      minimum_gap
    },
    recovery_points: if recovery_points < 1 {
      1
    } else {
      recovery_points
    },
    action,
    severity,
    budget_per_window: if budget_per_window < 1 {
      1
    } else {
      budget_per_window
    },
    budget_window: if budget_window < 1L {
      1L
    } else {
      budget_window
    },
  }
}

///|
pub fn ProductionAlertConfig::minimum_score(
  self : ProductionAlertConfig,
) -> Double {
  self.minimum_score
}

///|
pub fn ProductionAlertConfig::minimum_confidence(
  self : ProductionAlertConfig,
) -> Double {
  self.minimum_confidence
}

///|
pub fn ProductionAlertConfig::minimum_gap(
  self : ProductionAlertConfig,
) -> Int64 {
  self.minimum_gap
}

///|
pub fn ProductionAlertConfig::recovery_points(
  self : ProductionAlertConfig,
) -> Int {
  self.recovery_points
}

///|
pub fn ProductionAlertConfig::action(
  self : ProductionAlertConfig,
) -> RecoveryAction {
  self.action
}

///|
pub fn ProductionAlertConfig::severity(
  self : ProductionAlertConfig,
) -> AlertSeverity {
  self.severity
}

///|
pub fn ProductionAlertConfig::budget_per_window(
  self : ProductionAlertConfig,
) -> Int {
  self.budget_per_window
}

///|
pub fn ProductionAlertConfig::budget_window(
  self : ProductionAlertConfig,
) -> Int64 {
  self.budget_window
}

///|
/// Complete configuration for one production monitor.
pub struct ProductionMonitorConfig {
  name : String
  mode : ProductionMonitorMode
  missing_values : MissingValueStrategy
  baseline : ProductionBaselineStrategy
  fixed_baseline : Double
  detection : ProductionDetectionConfig
  window : ProductionWindowConfig
  alerts : ProductionAlertConfig
  dimensions : Int
  version : Int
}

///|
pub fn ProductionMonitorConfig::new(
  name? : String = "metric",
  mode? : ProductionMonitorMode = Alerting,
  missing_values? : MissingValueStrategy = DropValue,
  baseline? : ProductionBaselineStrategy = RollingMedian,
  fixed_baseline? : Double = 0.0,
  detection? : ProductionDetectionConfig = ProductionDetectionConfig::new(),
  window? : ProductionWindowConfig = ProductionWindowConfig::new(),
  alerts? : ProductionAlertConfig = ProductionAlertConfig::new(),
  dimensions? : Int = 1,
  version? : Int = 1,
) -> ProductionMonitorConfig {
  {
    name,
    mode,
    missing_values,
    baseline,
    fixed_baseline,
    detection,
    window,
    alerts,
    dimensions: if dimensions < 1 {
      1
    } else {
      dimensions
    },
    version: if version < 1 {
      1
    } else {
      version
    },
  }
}

///|
pub fn ProductionMonitorConfig::name(self : ProductionMonitorConfig) -> String {
  self.name
}

///|
pub fn ProductionMonitorConfig::mode(
  self : ProductionMonitorConfig,
) -> ProductionMonitorMode {
  self.mode
}

///|
pub fn ProductionMonitorConfig::missing_values(
  self : ProductionMonitorConfig,
) -> MissingValueStrategy {
  self.missing_values
}

///|
pub fn ProductionMonitorConfig::baseline(
  self : ProductionMonitorConfig,
) -> ProductionBaselineStrategy {
  self.baseline
}

///|
pub fn ProductionMonitorConfig::fixed_baseline(
  self : ProductionMonitorConfig,
) -> Double {
  self.fixed_baseline
}

///|
pub fn ProductionMonitorConfig::detection(
  self : ProductionMonitorConfig,
) -> ProductionDetectionConfig {
  self.detection
}

///|
pub fn ProductionMonitorConfig::window(
  self : ProductionMonitorConfig,
) -> ProductionWindowConfig {
  self.window
}

///|
pub fn ProductionMonitorConfig::alerts(
  self : ProductionMonitorConfig,
) -> ProductionAlertConfig {
  self.alerts
}

///|
pub fn ProductionMonitorConfig::dimensions(
  self : ProductionMonitorConfig,
) -> Int {
  self.dimensions
}

///|
pub fn ProductionMonitorConfig::version(self : ProductionMonitorConfig) -> Int {
  self.version
}

///|
/// Validates a complete configuration without throwing, suitable for CI and startup checks.
pub fn ProductionMonitorConfig::validate(
  self : ProductionMonitorConfig,
) -> Array[ProductionConfigIssue] {
  let issues : Array[ProductionConfigIssue] = []
  if self.name.length() == 0 {
    issues.push(ProductionConfigIssue::new("name", "must not be empty"))
  }
  if self.detection.detector_name().length() == 0 {
    issues.push(
      ProductionConfigIssue::new("detection.detector_name", "must not be empty"),
    )
  }
  if self.detection.confidence() < 0.0 || self.detection.confidence() > 1.0 {
    issues.push(
      ProductionConfigIssue::new("detection.confidence", "must be in [0,1]"),
    )
  }
  if self.window.allowed_lateness() < 0L {
    issues.push(
      ProductionConfigIssue::new(
        "window.allowed_lateness", "must be non-negative",
      ),
    )
  }
  if self.window.aggregate_size() < 1 {
    issues.push(
      ProductionConfigIssue::new("window.aggregate_size", "must be positive"),
    )
  }
  if self.window.retention_points() < self.window.aggregate_size() {
    issues.push(
      ProductionConfigIssue::new(
        "window.retention_points", "must cover at least one aggregate",
      ),
    )
  }
  if self.dimensions < 1 {
    issues.push(ProductionConfigIssue::new("dimensions", "must be positive"))
  }
  if !is_finite(self.fixed_baseline) {
    issues.push(ProductionConfigIssue::new("fixed_baseline", "must be finite"))
  }
  issues
}

///|
pub fn ProductionMonitorConfig::is_valid(
  self : ProductionMonitorConfig,
) -> Bool {
  self.validate().length() == 0
}

///|
pub fn ProductionMonitorConfig::summary(
  self : ProductionMonitorConfig,
) -> String {
  "name=" +
  self.name +
  ",version=" +
  self.version.to_string() +
  ",dimensions=" +
  self.dimensions.to_string() +
  ",detector=" +
  self.detection.detector_name() +
  ",aggregate=" +
  self.window.aggregate_size().to_string() +
  ",lateness=" +
  self.window.allowed_lateness().to_string()
}

///|
/// Returns the enum value as a stable configuration token.
pub fn production_mode_name(mode : ProductionMonitorMode) -> String {
  match mode {
    ObserveOnly => "observe"
    Alerting => "alerting"
    Backfill => "backfill"
    Replay => "replay"
  }
}

///|
pub fn missing_value_strategy_name(strategy : MissingValueStrategy) -> String {
  match strategy {
    DropValue => "drop"
    ImputeLast => "last"
    ImputeMean => "mean"
    ImputeZero => "zero"
    MarkUnknown => "unknown"
  }
}

///|
pub fn baseline_strategy_name(strategy : ProductionBaselineStrategy) -> String {
  match strategy {
    FixedBaseline => "fixed"
    RollingMedian => "rolling-median"
    RollingMean => "rolling-mean"
    ExponentiallyWeighted => "ewma"
    SeasonalBaseline => "seasonal"
  }
}

///|
pub fn recovery_action_name(action : RecoveryAction) -> String {
  match action {
    KeepOpen => "keep-open"
    AutoResolve => "auto-resolve"
    RequireAcknowledgement => "acknowledge"
    Escalate => "escalate"
  }
}

///|
/// A stable line-oriented representation used in deployment logs.
pub fn production_config_lines(
  config : ProductionMonitorConfig,
) -> Array[String] {
  [
    "name=" + config.name(),
    "version=" + config.version().to_string(),
    "mode=" + production_mode_name(config.mode()),
    "missing_values=" + missing_value_strategy_name(config.missing_values()),
    "baseline=" + baseline_strategy_name(config.baseline()),
    "fixed_baseline=" + config.fixed_baseline().to_string(),
    "detector=" + config.detection().detector_name(),
    "threshold=" + config.detection().threshold().to_string(),
    "confidence=" + config.detection().confidence().to_string(),
    "warmup_points=" + config.detection().warmup_points().to_string(),
    "aggregate_size=" + config.window().aggregate_size().to_string(),
    "allowed_lateness=" + config.window().allowed_lateness().to_string(),
    "retention_points=" + config.window().retention_points().to_string(),
    "minimum_score=" + config.alerts().minimum_score().to_string(),
    "minimum_confidence=" + config.alerts().minimum_confidence().to_string(),
    "minimum_gap=" + config.alerts().minimum_gap().to_string(),
    "recovery_points=" + config.alerts().recovery_points().to_string(),
    "recovery_action=" + recovery_action_name(config.alerts().action()),
    "dimensions=" + config.dimensions().to_string(),
  ]
}

///|
/// Returns a copy with a bumped configuration version.
pub fn ProductionMonitorConfig::next_version(
  self : ProductionMonitorConfig,
) -> ProductionMonitorConfig {
  {
    name: self.name,
    mode: self.mode,
    missing_values: self.missing_values,
    baseline: self.baseline,
    fixed_baseline: self.fixed_baseline,
    detection: self.detection,
    window: self.window,
    alerts: self.alerts,
    dimensions: self.dimensions,
    version: self.version + 1,
  }
}

///|
/// Determines whether a result is actionable for the configured mode.
pub fn ProductionMonitorConfig::is_actionable(
  self : ProductionMonitorConfig,
  result : DetectionResult,
) -> Bool {
  match self.mode {
    ObserveOnly => false
    Backfill => false
    Replay => self.detection.accepts(result)
    Alerting => self.detection.accepts(result)
  }
}

///|
/// A compact configuration fingerprint for cache keys and deployment audits.
pub fn ProductionMonitorConfig::fingerprint(
  self : ProductionMonitorConfig,
) -> String {
  let lines = production_config_lines(self)
  let mut checksum = 17
  for line in lines {
    for character in line {
      checksum = (checksum * 31 + character.to_int()) % 2147483647
    }
  }
  "cfg-{checksum}"
}

///|
pub fn production_config_issues_summary(
  issues : Array[ProductionConfigIssue],
) -> String {
  if issues.length() == 0 {
    return "valid"
  }
  let result : Array[String] = []
  for issue in issues {
    result.push(issue.summary())
  }
  result.join(";")
}

///|
fn production_directions_match(
  expected : ChangeDirection,
  actual : ChangeDirection,
) -> Bool {
  match (expected, actual) {
    (Increase, Increase) => true
    (Decrease, Decrease) => true
    (VarianceIncrease, VarianceIncrease) => true
    (VarianceDecrease, VarianceDecrease) => true
    (DistributionShift, DistributionShift) => true
    (Unknown, Unknown) => true
    _ => false
  }
}
