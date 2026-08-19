///|
/// Lifecycle state of an online production monitor.
pub(all) enum ProductionHealthState {
  ColdStart
  Healthy
  DegradedQuality
  AlertingState
  RecoveringState
  DisabledState
}

///|
/// Reason carried by an audit event emitted from a monitor.
pub(all) enum ProductionMonitorEventKind {
  Observation
  InvalidInput
  WarmupObservation
  ChangeDetected
  AlertEmitted
  AlertSuppressed
  RecoveryStarted
  RecoveryCompleted
  QualityDegraded
}

///|
pub fn production_health_state_name(state : ProductionHealthState) -> String {
  match state {
    ColdStart => "cold-start"
    Healthy => "healthy"
    DegradedQuality => "degraded-quality"
    AlertingState => "alerting"
    RecoveringState => "recovering"
    DisabledState => "disabled"
  }
}

///|
pub fn production_monitor_event_name(
  kind : ProductionMonitorEventKind,
) -> String {
  match kind {
    Observation => "observation"
    InvalidInput => "invalid-input"
    WarmupObservation => "warmup"
    ChangeDetected => "change-detected"
    AlertEmitted => "alert-emitted"
    AlertSuppressed => "alert-suppressed"
    RecoveryStarted => "recovery-started"
    RecoveryCompleted => "recovery-completed"
    QualityDegraded => "quality-degraded"
  }
}

///|
/// A durable audit record for each significant state transition.
pub struct ProductionMonitorEvent {
  metric : String
  timestamp : Int64
  sequence : Int
  kind : ProductionMonitorEventKind
  state : ProductionHealthState
  result : DetectionResult
  baseline : Double
  value : Double
  message : String
  ordinal : Int
}

///|
pub fn ProductionMonitorEvent::metric(self : ProductionMonitorEvent) -> String {
  self.metric
}

///|
pub fn ProductionMonitorEvent::timestamp(
  self : ProductionMonitorEvent,
) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionMonitorEvent::sequence(self : ProductionMonitorEvent) -> Int {
  self.sequence
}

///|
pub fn ProductionMonitorEvent::kind(
  self : ProductionMonitorEvent,
) -> ProductionMonitorEventKind {
  self.kind
}

///|
pub fn ProductionMonitorEvent::state(
  self : ProductionMonitorEvent,
) -> ProductionHealthState {
  self.state
}

///|
pub fn ProductionMonitorEvent::result(
  self : ProductionMonitorEvent,
) -> DetectionResult {
  self.result
}

///|
pub fn ProductionMonitorEvent::baseline(
  self : ProductionMonitorEvent,
) -> Double {
  self.baseline
}

///|
pub fn ProductionMonitorEvent::value(self : ProductionMonitorEvent) -> Double {
  self.value
}

///|
pub fn ProductionMonitorEvent::message(self : ProductionMonitorEvent) -> String {
  self.message
}

///|
pub fn ProductionMonitorEvent::ordinal(self : ProductionMonitorEvent) -> Int {
  self.ordinal
}

///|
pub fn ProductionMonitorEvent::summary(self : ProductionMonitorEvent) -> String {
  self.metric +
  "@" +
  self.timestamp.to_string() +
  " " +
  production_monitor_event_name(self.kind) +
  " state=" +
  production_health_state_name(self.state) +
  " score=" +
  self.result.score.to_string() +
  " baseline=" +
  self.baseline.to_string()
}

///|
/// A compact operational snapshot suitable for a dashboard or heartbeat endpoint.
pub struct ProductionMonitorSnapshot {
  name : String
  state : ProductionHealthState
  processed : Int
  valid : Int
  invalid : Int
  warmup_remaining : Int
  changes : Int
  emitted : Int
  suppressed : Int
  recovery_count : Int
  latest_score : Double
  baseline : Double
  latest_value : Double
  quality_ratio : Double
  last_timestamp : Int64
}

///|
pub fn ProductionMonitorSnapshot::name(
  self : ProductionMonitorSnapshot,
) -> String {
  self.name
}

///|
pub fn ProductionMonitorSnapshot::state(
  self : ProductionMonitorSnapshot,
) -> ProductionHealthState {
  self.state
}

///|
pub fn ProductionMonitorSnapshot::processed(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.processed
}

///|
pub fn ProductionMonitorSnapshot::valid(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.valid
}

///|
pub fn ProductionMonitorSnapshot::invalid(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.invalid
}

///|
pub fn ProductionMonitorSnapshot::warmup_remaining(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.warmup_remaining
}

///|
pub fn ProductionMonitorSnapshot::changes(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.changes
}

///|
pub fn ProductionMonitorSnapshot::emitted(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.emitted
}

///|
pub fn ProductionMonitorSnapshot::suppressed(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.suppressed
}

///|
pub fn ProductionMonitorSnapshot::recovery_count(
  self : ProductionMonitorSnapshot,
) -> Int {
  self.recovery_count
}

///|
pub fn ProductionMonitorSnapshot::latest_score(
  self : ProductionMonitorSnapshot,
) -> Double {
  self.latest_score
}

///|
pub fn ProductionMonitorSnapshot::baseline(
  self : ProductionMonitorSnapshot,
) -> Double {
  self.baseline
}

///|
pub fn ProductionMonitorSnapshot::latest_value(
  self : ProductionMonitorSnapshot,
) -> Double {
  self.latest_value
}

///|
pub fn ProductionMonitorSnapshot::quality_ratio(
  self : ProductionMonitorSnapshot,
) -> Double {
  self.quality_ratio
}

///|
pub fn ProductionMonitorSnapshot::last_timestamp(
  self : ProductionMonitorSnapshot,
) -> Int64 {
  self.last_timestamp
}

///|
pub fn ProductionMonitorSnapshot::is_healthy(
  self : ProductionMonitorSnapshot,
) -> Bool {
  production_health_state_is(self.state, Healthy) && self.quality_ratio >= 0.95
}

///|
pub fn ProductionMonitorSnapshot::summary(
  self : ProductionMonitorSnapshot,
) -> String {
  "name=" +
  self.name +
  ",state=" +
  production_health_state_name(self.state) +
  ",processed=" +
  self.processed.to_string() +
  ",valid=" +
  self.valid.to_string() +
  ",invalid=" +
  self.invalid.to_string() +
  ",changes=" +
  self.changes.to_string() +
  ",emitted=" +
  self.emitted.to_string() +
  ",suppressed=" +
  self.suppressed.to_string() +
  ",quality=" +
  self.quality_ratio.to_string()
}

///|
/// Checkpoint data that can be persisted by an embedding service.
pub struct ProductionMonitorCheckpoint {
  config_fingerprint : String
  processed : Int
  valid : Int
  invalid : Int
  changes : Int
  emitted : Int
  suppressed : Int
  recovery_count : Int
  last_timestamp : Int64
  baseline : Double
  latest_value : Double
  latest_score : Double
  state : ProductionHealthState
  baseline_values : Array[Double]
  recent_values : Array[Double]
}

///|
pub fn ProductionMonitorCheckpoint::fingerprint(
  self : ProductionMonitorCheckpoint,
) -> String {
  self.config_fingerprint
}

///|
pub fn ProductionMonitorCheckpoint::processed(
  self : ProductionMonitorCheckpoint,
) -> Int {
  self.processed
}

///|
pub fn ProductionMonitorCheckpoint::valid(
  self : ProductionMonitorCheckpoint,
) -> Int {
  self.valid
}

///|
pub fn ProductionMonitorCheckpoint::invalid(
  self : ProductionMonitorCheckpoint,
) -> Int {
  self.invalid
}

///|
pub fn ProductionMonitorCheckpoint::changes(
  self : ProductionMonitorCheckpoint,
) -> Int {
  self.changes
}

///|
pub fn ProductionMonitorCheckpoint::state(
  self : ProductionMonitorCheckpoint,
) -> ProductionHealthState {
  self.state
}

///|
pub fn ProductionMonitorCheckpoint::baseline(
  self : ProductionMonitorCheckpoint,
) -> Double {
  self.baseline
}

///|
pub fn ProductionMonitorCheckpoint::latest_value(
  self : ProductionMonitorCheckpoint,
) -> Double {
  self.latest_value
}

///|
pub fn ProductionMonitorCheckpoint::recent_values(
  self : ProductionMonitorCheckpoint,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.recent_values {
    result.push(value)
  }
  result
}

///|
/// Stateful online monitor joining data quality, baselines, detection, and alert policy.
pub struct ProductionMonitor {
  config : ProductionMonitorConfig
  detector : PipelineDetector
  baseline_window : DoubleWindow
  recent_window : ProductionTimeWindow
  events : Array[ProductionMonitorEvent]
  mut state : ProductionHealthState
  mut processed : Int
  mut valid : Int
  mut invalid : Int
  mut changes : Int
  mut emitted : Int
  mut suppressed : Int
  mut recovery_count : Int
  mut consecutive_healthy : Int
  mut consecutive_alerts : Int
  mut ordinal : Int
  mut latest_score : Double
  mut latest_baseline : Double
  mut latest_value : Double
  mut last_timestamp : Int64
  mut last_value : Double?
}

///|
pub fn ProductionMonitor::new(
  config : ProductionMonitorConfig,
  detector : PipelineDetector,
) -> ProductionMonitor {
  let retention = config.window().retention_points()
  {
    config,
    detector,
    baseline_window: DoubleWindow::new(retention),
    recent_window: ProductionTimeWindow::new(capacity=retention),
    events: [],
    state: if config.is_valid() {
      ColdStart
    } else {
      DisabledState
    },
    processed: 0,
    valid: 0,
    invalid: 0,
    changes: 0,
    emitted: 0,
    suppressed: 0,
    recovery_count: 0,
    consecutive_healthy: 0,
    consecutive_alerts: 0,
    ordinal: 0,
    latest_score: 0.0,
    latest_baseline: config.fixed_baseline(),
    latest_value: 0.0,
    last_timestamp: 0L,
    last_value: None,
  }
}

///|
pub fn ProductionMonitor::config(
  self : ProductionMonitor,
) -> ProductionMonitorConfig {
  self.config
}

///|
pub fn ProductionMonitor::state(
  self : ProductionMonitor,
) -> ProductionHealthState {
  self.state
}

///|
pub fn ProductionMonitor::processed(self : ProductionMonitor) -> Int {
  self.processed
}

///|
pub fn ProductionMonitor::valid(self : ProductionMonitor) -> Int {
  self.valid
}

///|
pub fn ProductionMonitor::invalid(self : ProductionMonitor) -> Int {
  self.invalid
}

///|
pub fn ProductionMonitor::changes(self : ProductionMonitor) -> Int {
  self.changes
}

///|
pub fn ProductionMonitor::emitted(self : ProductionMonitor) -> Int {
  self.emitted
}

///|
pub fn ProductionMonitor::suppressed(self : ProductionMonitor) -> Int {
  self.suppressed
}

///|
pub fn ProductionMonitor::recovery_count(self : ProductionMonitor) -> Int {
  self.recovery_count
}

///|
pub fn ProductionMonitor::latest_score(self : ProductionMonitor) -> Double {
  self.latest_score
}

///|
pub fn ProductionMonitor::latest_baseline(self : ProductionMonitor) -> Double {
  self.latest_baseline
}

///|
pub fn ProductionMonitor::latest_value(self : ProductionMonitor) -> Double {
  self.latest_value
}

///|
pub fn ProductionMonitor::event_count(self : ProductionMonitor) -> Int {
  self.events.length()
}

///|
pub fn ProductionMonitor::events(
  self : ProductionMonitor,
) -> Array[ProductionMonitorEvent] {
  let result : Array[ProductionMonitorEvent] = []
  for event in self.events {
    result.push(event)
  }
  result
}

///|
fn ProductionMonitor::baseline(self : ProductionMonitor) -> Double {
  match self.config.baseline() {
    FixedBaseline => self.config.fixed_baseline()
    RollingMedian => self.baseline_window.median()
    RollingMean => self.baseline_window.mean()
    ExponentiallyWeighted =>
      match self.last_value {
        None => self.baseline_window.mean()
        Some(value) => value
      }
    SeasonalBaseline => self.baseline_window.median()
  }
}

///|
fn ProductionMonitor::sanitize(
  self : ProductionMonitor,
  value : Double,
) -> Double? {
  if is_finite(value) {
    return Some(value)
  }
  match self.config.missing_values() {
    DropValue => None
    MarkUnknown => None
    ImputeZero => Some(0.0)
    ImputeMean => Some(self.baseline_window.mean())
    ImputeLast =>
      match self.last_value {
        None => Some(self.baseline_window.mean())
        Some(previous) => Some(previous)
      }
  }
}

///|
fn ProductionMonitor::append_event(
  self : ProductionMonitor,
  timestamp : Int64,
  sequence : Int,
  kind : ProductionMonitorEventKind,
  result : DetectionResult,
  baseline : Double,
  value : Double,
  message : String,
) -> ProductionMonitorEvent {
  self.ordinal += 1
  let event = {
    metric: self.config.name(),
    timestamp,
    sequence,
    kind,
    state: self.state,
    result,
    baseline,
    value,
    message,
    ordinal: self.ordinal,
  }
  self.events.push(event)
  let retention = self.config.window().retention_points() * 2
  if self.events.length() > retention {
    ignore(self.events.remove(0))
  }
  event
}

///|
fn ProductionMonitor::update_state(
  self : ProductionMonitor,
  result : DetectionResult,
  quality_ok : Bool,
) -> ProductionMonitorEventKind {
  if !quality_ok {
    self.consecutive_healthy = 0
    self.state = DegradedQuality
    return QualityDegraded
  }
  let actionable = self.config.is_actionable(result)
  if actionable {
    self.changes += 1
    self.consecutive_alerts += 1
    self.consecutive_healthy = 0
    if production_health_state_is(self.state, RecoveringState) {
      self.state = AlertingState
      RecoveryStarted
    } else {
      self.state = AlertingState
      ChangeDetected
    }
  } else {
    self.consecutive_alerts = 0
    self.consecutive_healthy += 1
    if self.processed < self.config.detection().warmup_points() {
      self.state = ColdStart
      WarmupObservation
    } else if production_health_state_is(self.state, AlertingState) {
      self.state = RecoveringState
      self.recovery_count += 1
      RecoveryStarted
    } else if production_health_state_is(self.state, RecoveringState) &&
      self.consecutive_healthy >= self.config.alerts().recovery_points() {
      self.state = Healthy
      RecoveryCompleted
    } else {
      self.state = Healthy
      Observation
    }
  }
}

///|
pub fn ProductionMonitor::update(
  self : ProductionMonitor,
  sample : ProductionSample,
) -> ProductionMonitorEvent? {
  self.processed += 1
  self.last_timestamp = sample.timestamp()
  let sanitized = self.sanitize(sample.value())
  match sanitized {
    None => {
      self.invalid += 1
      self.state = DegradedQuality
      let quiet = DetectionResult::quiet(index=self.processed)
      Some(
        self.append_event(
          sample.timestamp(),
          sample.sequence(),
          InvalidInput,
          quiet,
          self.latest_baseline,
          sample.value(),
          "value rejected by missing-value policy",
        ),
      )
    }
    Some(value) => {
      self.valid += 1
      let imputed_sample = ProductionSample::new(
        sample.timestamp(),
        value,
        sequence=sample.sequence(),
        imputed=sample.imputed() || !is_finite(sample.value()),
        late=sample.late(),
      )
      ignore(self.recent_window.push(imputed_sample))
      let baseline = self.baseline()
      self.latest_baseline = baseline
      self.latest_value = value
      let warmup = self.config.detection().warmup_points()
      if !production_baseline_is(self.config.baseline(), FixedBaseline) ||
        self.baseline_window.length() < warmup {
        ignore(self.baseline_window.push(value))
      }
      self.last_value = Some(value)
      let result = self.detector.update(value, self.processed)
      self.latest_score = result.score
      let quality_ok = !sample.late || sample.timestamp() >= self.last_timestamp
      let kind = self.update_state(result, quality_ok)
      let accepted = self.config.is_actionable(result)
      let final_kind = if production_event_kind_is(kind, ChangeDetected) &&
        accepted {
        self.emitted += 1
        AlertEmitted
      } else if production_event_kind_is(kind, ChangeDetected) {
        self.suppressed += 1
        AlertSuppressed
      } else {
        kind
      }
      let message = if production_event_kind_is(final_kind, AlertEmitted) {
        "change accepted by alert policy"
      } else if production_event_kind_is(final_kind, AlertSuppressed) {
        "change observed but suppressed by mode or threshold"
      } else if production_event_kind_is(final_kind, QualityDegraded) {
        "sample quality below operating policy"
      } else {
        "sample processed"
      }
      Some(
        self.append_event(
          sample.timestamp(),
          sample.sequence(),
          final_kind,
          result,
          baseline,
          value,
          message,
        ),
      )
    }
  }
}

///|
pub fn ProductionMonitor::update_point(
  self : ProductionMonitor,
  point : SignalPoint,
) -> ProductionMonitorEvent? {
  self.update(
    ProductionSample::new(point.timestamp, point.value, sequence=point.sequence),
  )
}

///|
pub fn ProductionMonitor::update_batch(
  self : ProductionMonitor,
  samples : Array[ProductionSample],
) -> Array[ProductionMonitorEvent] {
  let result : Array[ProductionMonitorEvent] = []
  for sample in samples {
    match self.update(sample) {
      None => ()
      Some(event) => result.push(event)
    }
  }
  result
}

///|
pub fn ProductionMonitor::snapshot(
  self : ProductionMonitor,
) -> ProductionMonitorSnapshot {
  {
    name: self.config.name(),
    state: self.state,
    processed: self.processed,
    valid: self.valid,
    invalid: self.invalid,
    warmup_remaining: if self.processed >=
      self.config.detection().warmup_points() {
      0
    } else {
      self.config.detection().warmup_points() - self.processed
    },
    changes: self.changes,
    emitted: self.emitted,
    suppressed: self.suppressed,
    recovery_count: self.recovery_count,
    latest_score: self.latest_score,
    baseline: self.latest_baseline,
    latest_value: self.latest_value,
    quality_ratio: if self.processed == 0 {
      1.0
    } else {
      self.valid.to_double() / self.processed.to_double()
    },
    last_timestamp: self.last_timestamp,
  }
}

///|
pub fn ProductionMonitor::checkpoint(
  self : ProductionMonitor,
) -> ProductionMonitorCheckpoint {
  {
    config_fingerprint: self.config.fingerprint(),
    processed: self.processed,
    valid: self.valid,
    invalid: self.invalid,
    changes: self.changes,
    emitted: self.emitted,
    suppressed: self.suppressed,
    recovery_count: self.recovery_count,
    last_timestamp: self.last_timestamp,
    baseline: self.latest_baseline,
    latest_value: self.latest_value,
    latest_score: self.latest_score,
    state: self.state,
    baseline_values: self.baseline_window.to_array(),
    recent_values: self.recent_window.values(),
  }
}

///|
pub fn ProductionMonitor::recent_values(
  self : ProductionMonitor,
) -> Array[Double] {
  self.recent_window.values()
}

///|
pub fn ProductionMonitor::recent_summary(
  self : ProductionMonitor,
) -> ProductionWindowSummary {
  self.recent_window.summary()
}

///|
pub fn ProductionMonitor::reset(self : ProductionMonitor) -> Unit {
  self.baseline_window.clear()
  self.recent_window.clear()
  self.events.clear()
  self.state = if self.config.is_valid() { ColdStart } else { DisabledState }
  self.processed = 0
  self.valid = 0
  self.invalid = 0
  self.changes = 0
  self.emitted = 0
  self.suppressed = 0
  self.recovery_count = 0
  self.consecutive_healthy = 0
  self.consecutive_alerts = 0
  self.ordinal = 0
  self.latest_score = 0.0
  self.latest_baseline = self.config.fixed_baseline()
  self.latest_value = 0.0
  self.last_timestamp = 0L
  self.last_value = None
}

///|
/// Runs a monitor over a sorted signal and returns its final snapshot.
pub fn production_monitor_signal(
  monitor : ProductionMonitor,
  points : Array[SignalPoint],
) -> ProductionMonitorSnapshot {
  for point in points {
    ignore(monitor.update_point(point))
  }
  monitor.snapshot()
}

///|
pub fn production_monitor_events_csv_header() -> String {
  "metric,timestamp,sequence,event,state,score,confidence,baseline,value,ordinal\n"
}

///|
pub fn production_monitor_events_csv(
  events : Array[ProductionMonitorEvent],
) -> String {
  let mut output = production_monitor_events_csv_header()
  for event in events {
    output = output +
      event.metric() +
      "," +
      event.timestamp().to_string() +
      "," +
      event.sequence().to_string() +
      "," +
      production_monitor_event_name(event.kind()) +
      "," +
      production_health_state_name(event.state()) +
      "," +
      event.result().score.to_string() +
      "," +
      event.result().confidence.to_string() +
      "," +
      event.baseline().to_string() +
      "," +
      event.value().to_string() +
      "," +
      event.ordinal().to_string() +
      "\n"
  }
  output
}

///|
fn production_health_state_is(
  left : ProductionHealthState,
  right : ProductionHealthState,
) -> Bool {
  match (left, right) {
    (ColdStart, ColdStart) => true
    (Healthy, Healthy) => true
    (DegradedQuality, DegradedQuality) => true
    (AlertingState, AlertingState) => true
    (RecoveringState, RecoveringState) => true
    (DisabledState, DisabledState) => true
    _ => false
  }
}

///|
fn production_baseline_is(
  left : ProductionBaselineStrategy,
  right : ProductionBaselineStrategy,
) -> Bool {
  match (left, right) {
    (FixedBaseline, FixedBaseline) => true
    (RollingMedian, RollingMedian) => true
    (RollingMean, RollingMean) => true
    (ExponentiallyWeighted, ExponentiallyWeighted) => true
    (SeasonalBaseline, SeasonalBaseline) => true
    _ => false
  }
}

///|
fn production_event_kind_is(
  left : ProductionMonitorEventKind,
  right : ProductionMonitorEventKind,
) -> Bool {
  match (left, right) {
    (Observation, Observation) => true
    (InvalidInput, InvalidInput) => true
    (WarmupObservation, WarmupObservation) => true
    (ChangeDetected, ChangeDetected) => true
    (AlertEmitted, AlertEmitted) => true
    (AlertSuppressed, AlertSuppressed) => true
    (RecoveryStarted, RecoveryStarted) => true
    (RecoveryCompleted, RecoveryCompleted) => true
    (QualityDegraded, QualityDegraded) => true
    _ => false
  }
}
