///|
/// Report formats supported by the operational reporting helpers.
pub(all) enum ProductionReportFormat {
  CsvReport
  MarkdownReport
  LineReport
}

///|
pub fn production_report_format_name(format : ProductionReportFormat) -> String {
  match format {
    CsvReport => "csv"
    MarkdownReport => "markdown"
    LineReport => "line"
  }
}

///|
/// Options controlling report size and precision.
pub struct ProductionReportOptions {
  format : ProductionReportFormat
  include_events : Bool
  include_features : Bool
  maximum_rows : Int
  decimals : Int
}

///|
pub fn ProductionReportOptions::new(
  format? : ProductionReportFormat = MarkdownReport,
  include_events? : Bool = true,
  include_features? : Bool = true,
  maximum_rows? : Int = 256,
  decimals? : Int = 6,
) -> ProductionReportOptions {
  {
    format,
    include_events,
    include_features,
    maximum_rows: if maximum_rows < 1 {
      1
    } else {
      maximum_rows
    },
    decimals: if decimals < 0 {
      0
    } else if decimals > 15 {
      15
    } else {
      decimals
    },
  }
}

///|
pub fn ProductionReportOptions::format(
  self : ProductionReportOptions,
) -> ProductionReportFormat {
  self.format
}

///|
pub fn ProductionReportOptions::include_events(
  self : ProductionReportOptions,
) -> Bool {
  self.include_events
}

///|
pub fn ProductionReportOptions::include_features(
  self : ProductionReportOptions,
) -> Bool {
  self.include_features
}

///|
pub fn ProductionReportOptions::maximum_rows(
  self : ProductionReportOptions,
) -> Int {
  self.maximum_rows
}

///|
pub fn ProductionReportOptions::decimals(self : ProductionReportOptions) -> Int {
  self.decimals
}

///|
/// A time-series point prepared for dashboard rendering.
pub struct ProductionDashboardPoint {
  timestamp : Int64
  value : Double
  baseline : Double
  score : Double
  changed : Bool
  state : ProductionHealthState
}

///|
pub fn ProductionDashboardPoint::new(
  timestamp : Int64,
  value : Double,
  baseline : Double,
  result : DetectionResult,
  state : ProductionHealthState,
) -> ProductionDashboardPoint {
  {
    timestamp,
    value,
    baseline,
    score: result.score,
    changed: result.changed,
    state,
  }
}

///|
pub fn ProductionDashboardPoint::timestamp(
  self : ProductionDashboardPoint,
) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionDashboardPoint::value(
  self : ProductionDashboardPoint,
) -> Double {
  self.value
}

///|
pub fn ProductionDashboardPoint::baseline(
  self : ProductionDashboardPoint,
) -> Double {
  self.baseline
}

///|
pub fn ProductionDashboardPoint::score(
  self : ProductionDashboardPoint,
) -> Double {
  self.score
}

///|
pub fn ProductionDashboardPoint::changed(
  self : ProductionDashboardPoint,
) -> Bool {
  self.changed
}

///|
pub fn ProductionDashboardPoint::state(
  self : ProductionDashboardPoint,
) -> ProductionHealthState {
  self.state
}

///|
pub struct ProductionDashboardSeries {
  name : String
  points : Array[ProductionDashboardPoint]
  mut dropped : Int
}

///|
pub fn ProductionDashboardSeries::new(
  name : String,
  capacity? : Int = 512,
) -> ProductionDashboardSeries {
  ignore(capacity)
  { name, points: [], dropped: 0 }
}

///|
pub fn ProductionDashboardSeries::name(
  self : ProductionDashboardSeries,
) -> String {
  self.name
}

///|
pub fn ProductionDashboardSeries::push(
  self : ProductionDashboardSeries,
  point : ProductionDashboardPoint,
  capacity? : Int = 512,
) -> Unit {
  self.points.push(point)
  let safe_capacity = if capacity < 1 { 1 } else { capacity }
  while self.points.length() > safe_capacity {
    ignore(self.points.remove(0))
    self.dropped += 1
  }
}

///|
pub fn ProductionDashboardSeries::points(
  self : ProductionDashboardSeries,
) -> Array[ProductionDashboardPoint] {
  let result : Array[ProductionDashboardPoint] = []
  for point in self.points {
    result.push(point)
  }
  result
}

///|
pub fn ProductionDashboardSeries::length(
  self : ProductionDashboardSeries,
) -> Int {
  self.points.length()
}

///|
pub fn ProductionDashboardSeries::dropped(
  self : ProductionDashboardSeries,
) -> Int {
  self.dropped
}

///|
pub fn ProductionDashboardSeries::changed_count(
  self : ProductionDashboardSeries,
) -> Int {
  let mut count = 0
  for point in self.points {
    if point.changed() {
      count += 1
    }
  }
  count
}

///|
pub fn ProductionDashboardSeries::latest(
  self : ProductionDashboardSeries,
) -> ProductionDashboardPoint? {
  if self.points.length() == 0 {
    None
  } else {
    Some(self.points[self.points.length() - 1])
  }
}

///|
/// Counter set for monitoring ingestion and alert delivery itself.
pub struct ProductionTelemetryCounters {
  mut samples_received : Int
  mut samples_rejected : Int
  mut samples_imputed : Int
  mut late_samples : Int
  mut detector_updates : Int
  mut alerts_emitted : Int
  mut alerts_suppressed : Int
  mut incidents_opened : Int
  mut incidents_resolved : Int
  mut report_exports : Int
}

///|
pub fn ProductionTelemetryCounters::new() -> ProductionTelemetryCounters {
  {
    samples_received: 0,
    samples_rejected: 0,
    samples_imputed: 0,
    late_samples: 0,
    detector_updates: 0,
    alerts_emitted: 0,
    alerts_suppressed: 0,
    incidents_opened: 0,
    incidents_resolved: 0,
    report_exports: 0,
  }
}

///|
pub fn ProductionTelemetryCounters::observe_sample(
  self : ProductionTelemetryCounters,
  sample : ProductionSample,
  accepted : Bool,
) -> Unit {
  self.samples_received += 1
  if !accepted {
    self.samples_rejected += 1
  }
  if sample.imputed() {
    self.samples_imputed += 1
  }
  if sample.late() {
    self.late_samples += 1
  }
}

///|
pub fn ProductionTelemetryCounters::observe_result(
  self : ProductionTelemetryCounters,
  result : DetectionResult,
  emitted : Bool,
) -> Unit {
  self.detector_updates += 1
  if result.changed {
    if emitted {
      self.alerts_emitted += 1
    } else {
      self.alerts_suppressed += 1
    }
  }
}

///|
pub fn ProductionTelemetryCounters::observe_incident(
  self : ProductionTelemetryCounters,
  opened : Bool,
  resolved : Bool,
) -> Unit {
  if opened {
    self.incidents_opened += 1
  }
  if resolved {
    self.incidents_resolved += 1
  }
}

///|
pub fn ProductionTelemetryCounters::observe_export(
  self : ProductionTelemetryCounters,
) -> Unit {
  self.report_exports += 1
}

///|
pub fn ProductionTelemetryCounters::samples_received(
  self : ProductionTelemetryCounters,
) -> Int {
  self.samples_received
}

///|
pub fn ProductionTelemetryCounters::samples_rejected(
  self : ProductionTelemetryCounters,
) -> Int {
  self.samples_rejected
}

///|
pub fn ProductionTelemetryCounters::samples_imputed(
  self : ProductionTelemetryCounters,
) -> Int {
  self.samples_imputed
}

///|
pub fn ProductionTelemetryCounters::late_samples(
  self : ProductionTelemetryCounters,
) -> Int {
  self.late_samples
}

///|
pub fn ProductionTelemetryCounters::detector_updates(
  self : ProductionTelemetryCounters,
) -> Int {
  self.detector_updates
}

///|
pub fn ProductionTelemetryCounters::alerts_emitted(
  self : ProductionTelemetryCounters,
) -> Int {
  self.alerts_emitted
}

///|
pub fn ProductionTelemetryCounters::alerts_suppressed(
  self : ProductionTelemetryCounters,
) -> Int {
  self.alerts_suppressed
}

///|
pub fn ProductionTelemetryCounters::incidents_opened(
  self : ProductionTelemetryCounters,
) -> Int {
  self.incidents_opened
}

///|
pub fn ProductionTelemetryCounters::incidents_resolved(
  self : ProductionTelemetryCounters,
) -> Int {
  self.incidents_resolved
}

///|
pub fn ProductionTelemetryCounters::report_exports(
  self : ProductionTelemetryCounters,
) -> Int {
  self.report_exports
}

///|
pub fn ProductionTelemetryCounters::summary(
  self : ProductionTelemetryCounters,
) -> String {
  "received=" +
  self.samples_received.to_string() +
  ",rejected=" +
  self.samples_rejected.to_string() +
  ",imputed=" +
  self.samples_imputed.to_string() +
  ",late=" +
  self.late_samples.to_string() +
  ",updates=" +
  self.detector_updates.to_string() +
  ",emitted=" +
  self.alerts_emitted.to_string() +
  ",suppressed=" +
  self.alerts_suppressed.to_string() +
  ",opened=" +
  self.incidents_opened.to_string() +
  ",resolved=" +
  self.incidents_resolved.to_string() +
  ",exports=" +
  self.report_exports.to_string()
}

///|
/// Exports monitor snapshots as a stable CSV schema.
pub fn production_snapshots_csv_header() -> String {
  "name,state,processed,valid,invalid,warmup_remaining,changes,emitted,suppressed,recovery_count,latest_score,baseline,latest_value,quality,last_timestamp\n"
}

///|
pub fn production_snapshot_csv(snapshot : ProductionMonitorSnapshot) -> String {
  snapshot.name() +
  "," +
  production_health_state_name(snapshot.state()) +
  "," +
  snapshot.processed().to_string() +
  "," +
  snapshot.valid().to_string() +
  "," +
  snapshot.invalid().to_string() +
  "," +
  snapshot.warmup_remaining().to_string() +
  "," +
  snapshot.changes().to_string() +
  "," +
  snapshot.emitted().to_string() +
  "," +
  snapshot.suppressed().to_string() +
  "," +
  snapshot.recovery_count().to_string() +
  "," +
  snapshot.latest_score().to_string() +
  "," +
  snapshot.baseline().to_string() +
  "," +
  snapshot.latest_value().to_string() +
  "," +
  snapshot.quality_ratio().to_string() +
  "," +
  snapshot.last_timestamp().to_string() +
  "\n"
}

///|
pub fn production_snapshots_csv(
  snapshots : Array[ProductionMonitorSnapshot],
) -> String {
  let mut output = production_snapshots_csv_header()
  for snapshot in snapshots {
    output = output + production_snapshot_csv(snapshot)
  }
  output
}

///|
pub fn production_checkpoint_csv(
  checkpoint : ProductionMonitorCheckpoint,
) -> String {
  "fingerprint,processed,valid,invalid,changes,emitted,suppressed,recovery_count,last_timestamp,baseline,latest_value,latest_score,state\n" +
  checkpoint.fingerprint() +
  "," +
  checkpoint.processed().to_string() +
  "," +
  checkpoint.valid().to_string() +
  "," +
  checkpoint.invalid().to_string() +
  "," +
  checkpoint.changes().to_string() +
  "," +
  checkpoint.emitted.to_string() +
  "," +
  checkpoint.suppressed.to_string() +
  "," +
  checkpoint.recovery_count.to_string() +
  "," +
  checkpoint.last_timestamp.to_string() +
  "," +
  checkpoint.baseline().to_string() +
  "," +
  checkpoint.latest_value().to_string() +
  "," +
  checkpoint.latest_score.to_string() +
  "," +
  production_health_state_name(checkpoint.state()) +
  "\n"
}

///|
pub fn production_features_csv_header() -> String {
  "name,kind,value,valid,sample_count,source_window\n"
}

///|
pub fn production_features_csv(vector : ProductionFeatureVector) -> String {
  let mut output = production_features_csv_header()
  for feature in vector.features() {
    output = output +
      feature.name() +
      "," +
      production_feature_kind_name(feature.kind()) +
      "," +
      feature.value().to_string() +
      "," +
      feature.valid().to_string() +
      "," +
      feature.sample_count().to_string() +
      "," +
      feature.source_window().to_string() +
      "\n"
  }
  output
}

///|
pub fn production_incidents_markdown(
  incidents : Array[ProductionIncident],
) -> String {
  let mut output = "| id | metric | state | severity | alerts | max score | duration |\n|---:|---|---|---|---:|---:|---:|\n"
  for incident in incidents {
    output = output +
      "| " +
      incident.id().to_string() +
      " | " +
      incident.metric() +
      " | " +
      production_incident_state_name(incident.state()) +
      " | " +
      severity_name(incident.severity()) +
      " | " +
      incident.alert_count().to_string() +
      " | " +
      incident.max_score().to_string() +
      " | " +
      incident.duration().to_string() +
      " |\n"
  }
  output
}

///|
pub fn production_calibration_markdown(
  bins : Array[ProductionCalibrationBin],
) -> String {
  let mut output = "| lower | upper | count | positives | mean score | observed rate |\n|---:|---:|---:|---:|---:|---:|\n"
  for bin in bins {
    output = output +
      "| " +
      bin.lower().to_string() +
      " | " +
      bin.upper().to_string() +
      " | " +
      bin.count().to_string() +
      " | " +
      bin.positives().to_string() +
      " | " +
      bin.mean_score().to_string() +
      " | " +
      bin.observed_rate().to_string() +
      " |\n"
  }
  output
}

///|
pub fn production_drift_markdown(report : ProductionDriftReport) -> String {
  "| metric | value |\n|---|---:|\n" +
  "| baseline count | " +
  report.baseline_count().to_string() +
  " |\n" +
  "| current count | " +
  report.current_count().to_string() +
  " |\n" +
  "| mean shift | " +
  report.mean_shift().to_string() +
  " |\n" +
  "| variance ratio | " +
  report.variance_ratio().to_string() +
  " |\n" +
  "| KS distance | " +
  report.ks_distance().to_string() +
  " |\n" +
  "| energy distance | " +
  report.energy_distance().to_string() +
  " |\n" +
  "| drift score | " +
  report.drift_score().to_string() +
  " |\n" +
  "| drifted | " +
  report.drifted().to_string() +
  " |\n"
}

///|
/// Produces a bounded dashboard-friendly time series from monitor events.
pub fn production_dashboard_series(
  name : String,
  events : Array[ProductionMonitorEvent],
  maximum_rows? : Int = 512,
) -> ProductionDashboardSeries {
  let series = ProductionDashboardSeries::new(name, capacity=maximum_rows)
  let safe_rows = if maximum_rows < 1 { 1 } else { maximum_rows }
  for event in events {
    series.push(
      ProductionDashboardPoint::new(
        event.timestamp(),
        event.value(),
        event.baseline(),
        event.result(),
        event.state(),
      ),
      capacity=safe_rows,
    )
  }
  series
}

///|
pub fn production_dashboard_csv(series : ProductionDashboardSeries) -> String {
  let mut output = "timestamp,value,baseline,score,changed,state\n"
  for point in series.points() {
    output = output +
      point.timestamp().to_string() +
      "," +
      point.value().to_string() +
      "," +
      point.baseline().to_string() +
      "," +
      point.score().to_string() +
      "," +
      point.changed().to_string() +
      "," +
      production_health_state_name(point.state()) +
      "\n"
  }
  output
}

///|
pub fn production_incident_rate_markdown(
  incidents : Array[ProductionIncident],
  start : Int64,
  end : Int64,
) -> String {
  let rate = if end <= start {
    0.0
  } else {
    incidents.length().to_double() / (end - start).to_double()
  }
  "| metric | value |\n|---|---:|\n| incidents | " +
  incidents.length().to_string() +
  " |\n| rate | " +
  rate.to_string() +
  " |\n"
}
