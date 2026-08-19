///|
/// Lifecycle status of an embedding service.
pub(all) enum ProductionServiceStatus {
  StartingService
  ReadyService
  DegradedService
  DrainingService
  FailedService
}

///|
pub fn production_service_status_name(
  status : ProductionServiceStatus,
) -> String {
  match status {
    StartingService => "starting"
    ReadyService => "ready"
    DegradedService => "degraded"
    DrainingService => "draining"
    FailedService => "failed"
  }
}

///|
/// Result of one startup or liveness check.
pub struct ProductionReadinessCheck {
  name : String
  passed : Bool
  critical : Bool
  value : Double
  expected : Double
  message : String
}

///|
pub fn ProductionReadinessCheck::new(
  name : String,
  passed : Bool,
  expected : Double,
  value : Double,
  message? : String = "",
  critical? : Bool = true,
) -> ProductionReadinessCheck {
  { name, passed, critical, value, expected, message }
}

///|
pub fn ProductionReadinessCheck::name(
  self : ProductionReadinessCheck,
) -> String {
  self.name
}

///|
pub fn ProductionReadinessCheck::passed(
  self : ProductionReadinessCheck,
) -> Bool {
  self.passed
}

///|
pub fn ProductionReadinessCheck::critical(
  self : ProductionReadinessCheck,
) -> Bool {
  self.critical
}

///|
pub fn ProductionReadinessCheck::value(
  self : ProductionReadinessCheck,
) -> Double {
  self.value
}

///|
pub fn ProductionReadinessCheck::expected(
  self : ProductionReadinessCheck,
) -> Double {
  self.expected
}

///|
pub fn ProductionReadinessCheck::message(
  self : ProductionReadinessCheck,
) -> String {
  self.message
}

///|
pub fn ProductionReadinessCheck::summary(
  self : ProductionReadinessCheck,
) -> String {
  self.name +
  "=" +
  self.passed.to_string() +
  ",value=" +
  self.value.to_string() +
  ",expected=" +
  self.expected.to_string() +
  ",message=" +
  self.message
}

///|
/// Aggregate startup and liveness status.
pub struct ProductionReadinessReport {
  checks : Array[ProductionReadinessCheck]
  passed : Bool
  critical_failures : Int
  warnings : Int
  status : ProductionServiceStatus
}

///|
pub fn ProductionReadinessReport::from_checks(
  checks : Array[ProductionReadinessCheck],
) -> ProductionReadinessReport {
  let mut critical_failures = 0
  let mut warnings = 0
  for check in checks {
    if !check.passed() {
      if check.critical() {
        critical_failures += 1
      } else {
        warnings += 1
      }
    }
  }
  {
    checks,
    passed: critical_failures == 0,
    critical_failures,
    warnings,
    status: if critical_failures > 0 {
      FailedService
    } else if warnings > 0 {
      DegradedService
    } else {
      ReadyService
    },
  }
}

///|
pub fn ProductionReadinessReport::checks(
  self : ProductionReadinessReport,
) -> Array[ProductionReadinessCheck] {
  let result : Array[ProductionReadinessCheck] = []
  for check in self.checks {
    result.push(check)
  }
  result
}

///|
pub fn ProductionReadinessReport::passed(
  self : ProductionReadinessReport,
) -> Bool {
  self.passed
}

///|
pub fn ProductionReadinessReport::critical_failures(
  self : ProductionReadinessReport,
) -> Int {
  self.critical_failures
}

///|
pub fn ProductionReadinessReport::warnings(
  self : ProductionReadinessReport,
) -> Int {
  self.warnings
}

///|
pub fn ProductionReadinessReport::status(
  self : ProductionReadinessReport,
) -> ProductionServiceStatus {
  self.status
}

///|
pub fn ProductionReadinessReport::summary(
  self : ProductionReadinessReport,
) -> String {
  "status=" +
  production_service_status_name(self.status) +
  ",passed=" +
  self.passed.to_string() +
  ",critical_failures=" +
  self.critical_failures.to_string() +
  ",warnings=" +
  self.warnings.to_string()
}

///|
pub fn ProductionReadinessReport::markdown(
  self : ProductionReadinessReport,
) -> String {
  let mut output = "| check | passed | critical | value | expected | message |\n|---|---|---|---:|---:|---|\n"
  for check in self.checks {
    output = output +
      "| " +
      check.name() +
      " | " +
      check.passed().to_string() +
      " | " +
      check.critical().to_string() +
      " | " +
      check.value().to_string() +
      " | " +
      check.expected().to_string() +
      " | " +
      check.message() +
      " |\n"
  }
  output
}

///|
/// Heartbeat record for a service exposing monitor health.
pub struct ProductionServiceHeartbeat {
  service : String
  timestamp : Int64
  status : ProductionServiceStatus
  monitor_count : Int
  fleet_score : Double
  processed : Int
  alerts : Int
  incidents : Int
  p95_latency : Double
}

///|
pub fn ProductionServiceHeartbeat::new(
  service : String,
  timestamp : Int64,
  snapshots : Array[ProductionMonitorSnapshot],
  incidents : Int,
  p95_latency? : Double = 0.0,
) -> ProductionServiceHeartbeat {
  let score = production_fleet_health_score(snapshots)
  {
    service,
    timestamp,
    status: if score >= 0.9 {
      ReadyService
    } else if score >= 0.6 {
      DegradedService
    } else {
      FailedService
    },
    monitor_count: snapshots.length(),
    fleet_score: score,
    processed: production_snapshot_processed_total(snapshots),
    alerts: production_snapshot_alert_total(snapshots),
    incidents: if incidents < 0 {
      0
    } else {
      incidents
    },
    p95_latency: if p95_latency < 0.0 {
      0.0
    } else {
      p95_latency
    },
  }
}

///|
pub fn ProductionServiceHeartbeat::service(
  self : ProductionServiceHeartbeat,
) -> String {
  self.service
}

///|
pub fn ProductionServiceHeartbeat::timestamp(
  self : ProductionServiceHeartbeat,
) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionServiceHeartbeat::status(
  self : ProductionServiceHeartbeat,
) -> ProductionServiceStatus {
  self.status
}

///|
pub fn ProductionServiceHeartbeat::monitor_count(
  self : ProductionServiceHeartbeat,
) -> Int {
  self.monitor_count
}

///|
pub fn ProductionServiceHeartbeat::fleet_score(
  self : ProductionServiceHeartbeat,
) -> Double {
  self.fleet_score
}

///|
pub fn ProductionServiceHeartbeat::processed(
  self : ProductionServiceHeartbeat,
) -> Int {
  self.processed
}

///|
pub fn ProductionServiceHeartbeat::alerts(
  self : ProductionServiceHeartbeat,
) -> Int {
  self.alerts
}

///|
pub fn ProductionServiceHeartbeat::incidents(
  self : ProductionServiceHeartbeat,
) -> Int {
  self.incidents
}

///|
pub fn ProductionServiceHeartbeat::p95_latency(
  self : ProductionServiceHeartbeat,
) -> Double {
  self.p95_latency
}

///|
pub fn ProductionServiceHeartbeat::summary(
  self : ProductionServiceHeartbeat,
) -> String {
  self.service +
  "@" +
  self.timestamp.to_string() +
  " status=" +
  production_service_status_name(self.status) +
  " monitors=" +
  self.monitor_count.to_string() +
  " score=" +
  self.fleet_score.to_string() +
  " processed=" +
  self.processed.to_string() +
  " alerts=" +
  self.alerts.to_string() +
  " incidents=" +
  self.incidents.to_string() +
  " p95=" +
  self.p95_latency.to_string()
}

///|
/// A registry for coordinated monitor heartbeats.
pub struct ProductionServiceRegistry {
  service : String
  monitors : Array[ProductionMonitor]
  mut heartbeats : Int
  mut status : ProductionServiceStatus
}

///|
pub fn ProductionServiceRegistry::new(
  service? : String = "moon-change-point",
) -> ProductionServiceRegistry {
  { service, monitors: [], heartbeats: 0, status: StartingService }
}

///|
pub fn ProductionServiceRegistry::register(
  self : ProductionServiceRegistry,
  monitor : ProductionMonitor,
) -> Bool {
  for existing in self.monitors {
    if existing.config().name() == monitor.config().name() {
      return false
    }
  }
  self.monitors.push(monitor)
  true
}

///|
pub fn ProductionServiceRegistry::monitor_count(
  self : ProductionServiceRegistry,
) -> Int {
  self.monitors.length()
}

///|
pub fn ProductionServiceRegistry::names(
  self : ProductionServiceRegistry,
) -> Array[String] {
  let result : Array[String] = []
  for monitor in self.monitors {
    result.push(monitor.config().name())
  }
  result
}

///|
pub fn ProductionServiceRegistry::snapshots(
  self : ProductionServiceRegistry,
) -> Array[ProductionMonitorSnapshot] {
  let result : Array[ProductionMonitorSnapshot] = []
  for monitor in self.monitors {
    result.push(monitor.snapshot())
  }
  result
}

///|
pub fn ProductionServiceRegistry::heartbeat(
  self : ProductionServiceRegistry,
  timestamp : Int64,
  incidents : Int,
  p95_latency? : Double = 0.0,
) -> ProductionServiceHeartbeat {
  self.heartbeats += 1
  let heartbeat = ProductionServiceHeartbeat::new(
    self.service,
    timestamp,
    self.snapshots(),
    incidents,
    p95_latency~,
  )
  self.status = heartbeat.status()
  heartbeat
}

///|
pub fn ProductionServiceRegistry::heartbeats(
  self : ProductionServiceRegistry,
) -> Int {
  self.heartbeats
}

///|
pub fn ProductionServiceRegistry::status(
  self : ProductionServiceRegistry,
) -> ProductionServiceStatus {
  self.status
}

///|
pub fn ProductionServiceRegistry::process(
  self : ProductionServiceRegistry,
  metric_index : Int,
  sample : ProductionSample,
) -> ProductionMonitorEvent? {
  if metric_index < 0 || metric_index >= self.monitors.length() {
    return None
  }
  self.monitors[metric_index].update(sample)
}

///|
pub fn ProductionServiceRegistry::process_all(
  self : ProductionServiceRegistry,
  samples : Array[ProductionSample],
) -> Array[ProductionMonitorEvent] {
  let result : Array[ProductionMonitorEvent] = []
  for i, sample in samples {
    if self.monitors.length() > 0 {
      let index = i % self.monitors.length()
      match self.process(index, sample) {
        None => ()
        Some(event) => result.push(event)
      }
    }
  }
  result
}

///|
/// Summary of a bounded batch processing run.
pub struct ProductionBatchResult {
  batch_id : String
  input_count : Int
  accepted_count : Int
  rejected_count : Int
  event_count : Int
  alert_count : Int
  checksum : Double
  duration_ticks : Int64
}

///|
pub fn ProductionBatchResult::input_count(self : ProductionBatchResult) -> Int {
  self.input_count
}

///|
pub fn ProductionBatchResult::accepted_count(
  self : ProductionBatchResult,
) -> Int {
  self.accepted_count
}

///|
pub fn ProductionBatchResult::rejected_count(
  self : ProductionBatchResult,
) -> Int {
  self.rejected_count
}

///|
pub fn ProductionBatchResult::event_count(self : ProductionBatchResult) -> Int {
  self.event_count
}

///|
pub fn ProductionBatchResult::alert_count(self : ProductionBatchResult) -> Int {
  self.alert_count
}

///|
pub fn ProductionBatchResult::checksum(self : ProductionBatchResult) -> Double {
  self.checksum
}

///|
pub fn ProductionBatchResult::duration_ticks(
  self : ProductionBatchResult,
) -> Int64 {
  self.duration_ticks
}

///|
pub fn ProductionBatchResult::throughput(
  self : ProductionBatchResult,
) -> Double {
  if self.duration_ticks <= 0L {
    0.0
  } else {
    self.input_count.to_double() / self.duration_ticks.to_double()
  }
}

///|
pub fn ProductionBatchResult::summary(self : ProductionBatchResult) -> String {
  self.batch_id +
  ":input=" +
  self.input_count.to_string() +
  ",accepted=" +
  self.accepted_count.to_string() +
  ",rejected=" +
  self.rejected_count.to_string() +
  ",events=" +
  self.event_count.to_string() +
  ",alerts=" +
  self.alert_count.to_string() +
  ",checksum=" +
  self.checksum.to_string() +
  ",throughput=" +
  self.throughput().to_string()
}

///|
pub fn production_run_batch(
  batch_id : String,
  monitor : ProductionMonitor,
  samples : Array[ProductionSample],
) -> ProductionBatchResult {
  let events = monitor.update_batch(samples)
  let mut accepted = 0
  let mut rejected = 0
  let mut alerts = 0
  let mut checksum = 0.0
  for event in events {
    if event.kind() is InvalidInput {
      rejected += 1
    } else {
      accepted += 1
    }
    if event.result().changed {
      alerts += 1
    }
    checksum = checksum * 1.000001 +
      event.result().score +
      event.value() * 0.00001
  }
  {
    batch_id,
    input_count: samples.length(),
    accepted_count: accepted,
    rejected_count: rejected,
    event_count: accepted + rejected,
    alert_count: alerts,
    checksum,
    duration_ticks: if samples.length() == 0 {
      0L
    } else {
      samples[samples.length() - 1].timestamp() - samples[0].timestamp()
    },
  }
}

///|
pub fn production_startup_report(
  config : ProductionMonitorConfig,
  initial_values : Array[Double],
) -> ProductionReadinessReport {
  let checks : Array[ProductionReadinessCheck] = []
  let config_issues = config.validate()
  checks.push(
    ProductionReadinessCheck::new(
      "configuration",
      config_issues.length() == 0,
      1.0,
      if config_issues.length() == 0 {
        1.0
      } else {
        0.0
      },
      message=production_config_issues_summary(config_issues),
    ),
  )
  let quality = validate_values(initial_values)
  checks.push(
    ProductionReadinessCheck::new(
      "initial-data-quality",
      quality.is_healthy(),
      1.0,
      quality_score(quality),
      message=quality.is_healthy().to_string(),
      critical=false,
    ),
  )
  checks.push(
    ProductionReadinessCheck::new(
      "sample-volume",
      initial_values.length() >= config.detection().warmup_points(),
      config.detection().warmup_points().to_double(),
      initial_values.length().to_double(),
      message="warmup coverage",
    ),
  )
  ProductionReadinessReport::from_checks(checks)
}

///|
fn production_snapshot_processed_total(
  snapshots : Array[ProductionMonitorSnapshot],
) -> Int {
  let mut total = 0
  for snapshot in snapshots {
    total += snapshot.processed()
  }
  total
}

///|
fn production_snapshot_alert_total(
  snapshots : Array[ProductionMonitorSnapshot],
) -> Int {
  let mut total = 0
  for snapshot in snapshots {
    total += snapshot.emitted()
  }
  total
}
