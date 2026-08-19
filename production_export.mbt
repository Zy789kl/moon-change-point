///|
/// Wire formats supported by the production telemetry exporter.
pub(all) enum ProductionExportFormat {
  ExportJsonLines
  ExportCsv
  ExportPrometheus
  ExportMarkdown
  ExportSummaryJson
}

///|
pub fn production_export_format_name(format : ProductionExportFormat) -> String {
  match format {
    ExportJsonLines => "jsonl"
    ExportCsv => "csv"
    ExportPrometheus => "prometheus"
    ExportMarkdown => "markdown"
    ExportSummaryJson => "summary-json"
  }
}

///|
/// Fields that can be selected in a telemetry export.
pub(all) enum ProductionExportField {
  ExportTimestamp
  ExportMetric
  ExportValue
  ExportBaseline
  ExportScore
  ExportHealth
  ExportState
  ExportSource
}

///|
pub fn production_export_field_name(field : ProductionExportField) -> String {
  match field {
    ExportTimestamp => "timestamp"
    ExportMetric => "metric"
    ExportValue => "value"
    ExportBaseline => "baseline"
    ExportScore => "score"
    ExportHealth => "health"
    ExportState => "state"
    ExportSource => "source"
  }
}

///|
/// Export settings shared by all serializers.
pub struct ProductionExportOptions {
  format : ProductionExportFormat
  delimiter : String
  include_header : Bool
  include_metadata : Bool
  pretty : Bool
  max_records : Int
  metric_prefix : String
  metric_namespace : String
  line_ending : String
}

///|
pub fn ProductionExportOptions::new(
  format? : ProductionExportFormat = ExportJsonLines,
  delimiter? : String = ",",
  include_header? : Bool = true,
  include_metadata? : Bool = false,
  pretty? : Bool = false,
  max_records? : Int = 10000,
  metric_prefix? : String = "",
  metric_namespace? : String = "moon_change_point",
  line_ending? : String = "\n",
) -> ProductionExportOptions {
  {
    format,
    delimiter: if delimiter.length() == 0 {
      ","
    } else {
      delimiter
    },
    include_header,
    include_metadata,
    pretty,
    max_records: if max_records < 1 {
      1
    } else {
      max_records
    },
    metric_prefix,
    metric_namespace,
    line_ending: if line_ending.length() == 0 {
      "\n"
    } else {
      line_ending
    },
  }
}

///|
pub fn ProductionExportOptions::format(
  self : ProductionExportOptions,
) -> ProductionExportFormat {
  self.format
}

///|
pub fn ProductionExportOptions::delimiter(
  self : ProductionExportOptions,
) -> String {
  self.delimiter
}

///|
pub fn ProductionExportOptions::include_header(
  self : ProductionExportOptions,
) -> Bool {
  self.include_header
}

///|
pub fn ProductionExportOptions::include_metadata(
  self : ProductionExportOptions,
) -> Bool {
  self.include_metadata
}

///|
pub fn ProductionExportOptions::pretty(self : ProductionExportOptions) -> Bool {
  self.pretty
}

///|
pub fn ProductionExportOptions::max_records(
  self : ProductionExportOptions,
) -> Int {
  self.max_records
}

///|
pub fn ProductionExportOptions::metric_prefix(
  self : ProductionExportOptions,
) -> String {
  self.metric_prefix
}

///|
pub fn ProductionExportOptions::metric_namespace(
  self : ProductionExportOptions,
) -> String {
  self.metric_namespace
}

///|
pub fn ProductionExportOptions::line_ending(
  self : ProductionExportOptions,
) -> String {
  self.line_ending
}

///|
pub fn ProductionExportOptions::with_format(
  self : ProductionExportOptions,
  format : ProductionExportFormat,
) -> ProductionExportOptions {
  {
    format,
    delimiter: self.delimiter,
    include_header: self.include_header,
    include_metadata: self.include_metadata,
    pretty: self.pretty,
    max_records: self.max_records,
    metric_prefix: self.metric_prefix,
    metric_namespace: self.metric_namespace,
    line_ending: self.line_ending,
  }
}

///|
/// One normalized telemetry row emitted by a monitor or replay.
pub struct ProductionExportRecord {
  timestamp : Int64
  metric : String
  value : Double
  baseline : Double
  score : Double
  health : Double
  state : String
  source : String
}

///|
pub fn ProductionExportRecord::new(
  timestamp : Int64,
  metric : String,
  value : Double,
  baseline? : Double = 0.0,
  score? : Double = 0.0,
  health? : Double = 1.0,
  state? : String = "unknown",
  source? : String = "runtime",
) -> ProductionExportRecord {
  {
    timestamp,
    metric,
    value,
    baseline,
    score,
    health: clamp_probability(health),
    state,
    source,
  }
}

///|
pub fn ProductionExportRecord::timestamp(
  self : ProductionExportRecord,
) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionExportRecord::metric(self : ProductionExportRecord) -> String {
  self.metric
}

///|
pub fn ProductionExportRecord::value(self : ProductionExportRecord) -> Double {
  self.value
}

///|
pub fn ProductionExportRecord::baseline(
  self : ProductionExportRecord,
) -> Double {
  self.baseline
}

///|
pub fn ProductionExportRecord::score(self : ProductionExportRecord) -> Double {
  self.score
}

///|
pub fn ProductionExportRecord::health(self : ProductionExportRecord) -> Double {
  self.health
}

///|
pub fn ProductionExportRecord::state(self : ProductionExportRecord) -> String {
  self.state
}

///|
pub fn ProductionExportRecord::source(self : ProductionExportRecord) -> String {
  self.source
}

///|
pub fn ProductionExportRecord::is_finite(self : ProductionExportRecord) -> Bool {
  self.value == self.value &&
  self.value > -1.0e308 &&
  self.value < 1.0e308 &&
  self.baseline == self.baseline &&
  self.score == self.score
}

///|
pub fn ProductionExportRecord::with_state(
  self : ProductionExportRecord,
  state : String,
) -> ProductionExportRecord {
  {
    timestamp: self.timestamp,
    metric: self.metric,
    value: self.value,
    baseline: self.baseline,
    score: self.score,
    health: self.health,
    state,
    source: self.source,
  }
}

///|
pub fn ProductionExportRecord::field(
  self : ProductionExportRecord,
  field : ProductionExportField,
) -> String {
  match field {
    ExportTimestamp => self.timestamp.to_string()
    ExportMetric => self.metric
    ExportValue => self.value.to_string()
    ExportBaseline => self.baseline.to_string()
    ExportScore => self.score.to_string()
    ExportHealth => self.health.to_string()
    ExportState => self.state
    ExportSource => self.source
  }
}

///|
pub fn ProductionExportRecord::as_key(self : ProductionExportRecord) -> String {
  self.metric + ":" + self.timestamp.to_string()
}

///|
/// Bounded in-memory batch used to make exports deterministic.
pub struct ProductionExportBatch {
  mut records : Array[ProductionExportRecord]
  capacity : Int
  mut accepted : Int
  mut rejected : Int
  mut duplicate : Int
}

///|
pub fn ProductionExportBatch::new(
  capacity? : Int = 10000,
) -> ProductionExportBatch {
  {
    records: [],
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    accepted: 0,
    rejected: 0,
    duplicate: 0,
  }
}

///|
fn production_export_has_key(
  records : Array[ProductionExportRecord],
  key : String,
) -> Bool {
  for record in records {
    if record.as_key() == key {
      return true
    }
  }
  false
}

///|
pub fn ProductionExportBatch::add(
  self : ProductionExportBatch,
  record : ProductionExportRecord,
) -> Bool {
  if self.records.length() >= self.capacity || !record.is_finite() {
    self.rejected = self.rejected + 1
    false
  } else if production_export_has_key(self.records, record.as_key()) {
    self.duplicate = self.duplicate + 1
    false
  } else {
    self.records.push(record)
    self.accepted = self.accepted + 1
    true
  }
}

///|
pub fn ProductionExportBatch::add_many(
  self : ProductionExportBatch,
  records : Array[ProductionExportRecord],
) -> Int {
  let mut added = 0
  for record in records {
    if self.add(record) {
      added = added + 1
    }
  }
  added
}

///|
pub fn ProductionExportBatch::records(
  self : ProductionExportBatch,
) -> Array[ProductionExportRecord] {
  self.records[:].to_owned()
}

///|
pub fn ProductionExportBatch::capacity(self : ProductionExportBatch) -> Int {
  self.capacity
}

///|
pub fn ProductionExportBatch::count(self : ProductionExportBatch) -> Int {
  self.records.length()
}

///|
pub fn ProductionExportBatch::accepted(self : ProductionExportBatch) -> Int {
  self.accepted
}

///|
pub fn ProductionExportBatch::rejected(self : ProductionExportBatch) -> Int {
  self.rejected
}

///|
pub fn ProductionExportBatch::duplicate(self : ProductionExportBatch) -> Int {
  self.duplicate
}

///|
pub fn ProductionExportBatch::clear(self : ProductionExportBatch) -> Unit {
  self.records = []
  self.accepted = 0
  self.rejected = 0
  self.duplicate = 0
}

///|
/// Return records ordered by event time without mutating the input batch.
pub fn ProductionExportBatch::ordered(
  self : ProductionExportBatch,
) -> Array[ProductionExportRecord] {
  let ordered : Array[ProductionExportRecord] = []
  for record in self.records {
    let mut inserted = false
    for i = 0; i < ordered.length(); i = i + 1 {
      if record.timestamp() < ordered[i].timestamp() {
        ordered.insert(i, record)
        inserted = true
        break
      }
    }
    if !inserted {
      ordered.push(record)
    }
  }
  ordered
}

///|
fn production_export_json_escape(raw : String) -> String {
  let pieces : Array[String] = []
  for character in raw {
    match character.to_int() {
      34 => pieces.push("\\\"")
      92 => pieces.push("\\\\")
      10 => pieces.push("\\n")
      13 => pieces.push("\\r")
      9 => pieces.push("\\t")
      _ => pieces.push(character.to_string())
    }
  }
  pieces.join("")
}

///|
fn production_export_csv_escape(raw : String, delimiter : String) -> String {
  let mut needs_quotes = false
  if raw.contains(delimiter) || raw.contains("\"") || raw.contains("\n") {
    needs_quotes = true
  }
  let pieces : Array[String] = []
  for character in raw {
    if character.to_int() == 34 {
      pieces.push("\"\"")
    } else {
      pieces.push(character.to_string())
    }
  }
  if needs_quotes {
    "\"" + pieces.join("") + "\""
  } else {
    pieces.join("")
  }
}

///|
fn production_export_prometheus_name(
  options : ProductionExportOptions,
  metric : String,
) -> String {
  let pieces : Array[String] = []
  for
    character in options.metric_namespace() +
    "_" +
    options.metric_prefix() +
    metric {
    let code = character.to_int()
    if (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      code == 95 {
      pieces.push(character.to_string())
    } else {
      pieces.push("_")
    }
  }
  pieces.join("")
}

///|
pub fn production_export_record_json(
  record : ProductionExportRecord,
  pretty? : Bool = false,
) -> String {
  let separator = if pretty { ", " } else { "," }
  "{\"timestamp\":" +
  record.timestamp().to_string() +
  separator +
  "\"metric\":\"" +
  production_export_json_escape(record.metric()) +
  "\"" +
  separator +
  "\"value\":" +
  record.value().to_string() +
  separator +
  "\"baseline\":" +
  record.baseline().to_string() +
  separator +
  "\"score\":" +
  record.score().to_string() +
  separator +
  "\"health\":" +
  record.health().to_string() +
  separator +
  "\"state\":\"" +
  production_export_json_escape(record.state()) +
  "\"" +
  separator +
  "\"source\":\"" +
  production_export_json_escape(record.source()) +
  "\"}"
}

///|
pub fn production_export_record_csv(
  record : ProductionExportRecord,
  delimiter? : String = ",",
) -> String {
  let safe_delimiter = if delimiter.length() == 0 { "," } else { delimiter }
  let fields : Array[String] = []
  fields.push(record.timestamp().to_string())
  fields.push(production_export_csv_escape(record.metric(), safe_delimiter))
  fields.push(record.value().to_string())
  fields.push(record.baseline().to_string())
  fields.push(record.score().to_string())
  fields.push(record.health().to_string())
  fields.push(production_export_csv_escape(record.state(), safe_delimiter))
  fields.push(production_export_csv_escape(record.source(), safe_delimiter))
  fields.join(safe_delimiter)
}

///|
pub fn production_export_record_prometheus(
  record : ProductionExportRecord,
  options : ProductionExportOptions,
) -> String {
  let name = production_export_prometheus_name(options, record.metric())
  name +
  "{state=\"" +
  production_export_json_escape(record.state()) +
  "\",source=\"" +
  production_export_json_escape(record.source()) +
  "\"} " +
  record.value().to_string() +
  " " +
  record.timestamp().to_string()
}

///|
pub fn production_export_record_markdown(
  record : ProductionExportRecord,
) -> String {
  "| " +
  record.timestamp().to_string() +
  " | " +
  record.metric() +
  " | " +
  record.value().to_string() +
  " | " +
  record.baseline().to_string() +
  " | " +
  record.score().to_string() +
  " | " +
  record.health().to_string() +
  " | " +
  record.state() +
  " | " +
  record.source() +
  " |"
}

///|

///|
/// Exporter counters are kept separately from the batch so operators can
/// monitor serialization failures across multiple flushes.
pub struct ProductionExportStats {
  mut batches : Int
  mut records : Int
  mut bytes : Int
  failures : Int
  mut truncated : Int
}

///|
pub fn ProductionExportStats::new() -> ProductionExportStats {
  { batches: 0, records: 0, bytes: 0, failures: 0, truncated: 0 }
}

///|
pub fn ProductionExportStats::batches(self : ProductionExportStats) -> Int {
  self.batches
}

///|
pub fn ProductionExportStats::records(self : ProductionExportStats) -> Int {
  self.records
}

///|
pub fn ProductionExportStats::bytes(self : ProductionExportStats) -> Int {
  self.bytes
}

///|
pub fn ProductionExportStats::failures(self : ProductionExportStats) -> Int {
  self.failures
}

///|
pub fn ProductionExportStats::truncated(self : ProductionExportStats) -> Int {
  self.truncated
}

///|
pub fn ProductionExportStats::success_rate(
  self : ProductionExportStats,
) -> Double {
  if self.batches == 0 {
    1.0
  } else {
    (self.batches - self.failures).to_double() / self.batches.to_double()
  }
}

///|
pub fn ProductionExportStats::summary(self : ProductionExportStats) -> String {
  "batches=" +
  self.batches.to_string() +
  " records=" +
  self.records.to_string() +
  " bytes=" +
  self.bytes.to_string() +
  " failures=" +
  self.failures.to_string() +
  " truncated=" +
  self.truncated.to_string()
}

///|
pub struct ProductionTelemetryExporter {
  options : ProductionExportOptions
  mut stats : ProductionExportStats
}

///|
pub fn ProductionTelemetryExporter::new(
  options? : ProductionExportOptions = ProductionExportOptions::new(),
) -> ProductionTelemetryExporter {
  { options, stats: ProductionExportStats::new() }
}

///|
pub fn ProductionTelemetryExporter::options(
  self : ProductionTelemetryExporter,
) -> ProductionExportOptions {
  self.options
}

///|
pub fn ProductionTelemetryExporter::stats(
  self : ProductionTelemetryExporter,
) -> ProductionExportStats {
  self.stats
}

///|
fn ProductionTelemetryExporter::take_records(
  self : ProductionTelemetryExporter,
  batch : ProductionExportBatch,
) -> Array[ProductionExportRecord] {
  let records = batch.ordered()
  let limit = if records.length() > self.options.max_records() {
    self.stats.truncated = self.stats.truncated +
      records.length() -
      self.options.max_records()
    self.options.max_records()
  } else {
    records.length()
  }
  records[:limit].to_owned()
}

///|
pub fn ProductionTelemetryExporter::export_batch(
  self : ProductionTelemetryExporter,
  batch : ProductionExportBatch,
) -> String {
  self.stats.batches = self.stats.batches + 1
  let records = self.take_records(batch)
  self.stats.records = self.stats.records + records.length()
  let result = match self.options.format() {
    ExportJsonLines => self.export_json_lines(records)
    ExportCsv => self.export_csv(records)
    ExportPrometheus => self.export_prometheus(records)
    ExportMarkdown => self.export_markdown(records)
    ExportSummaryJson => self.export_summary(records)
  }
  self.stats.bytes = self.stats.bytes + result.length()
  result
}

///|
pub fn ProductionTelemetryExporter::export_json_lines(
  self : ProductionTelemetryExporter,
  records : Array[ProductionExportRecord],
) -> String {
  let lines : Array[String] = []
  if self.options.include_metadata() {
    lines.push(
      "{\"type\":\"metadata\",\"format\":\"jsonl\",\"namespace\":\"" +
      production_export_json_escape(self.options.metric_namespace()) +
      "\"}",
    )
  }
  for record in records {
    lines.push(
      production_export_record_json(record, pretty=self.options.pretty()),
    )
  }
  lines.join(self.options.line_ending())
}

///|
pub fn ProductionTelemetryExporter::export_csv(
  self : ProductionTelemetryExporter,
  records : Array[ProductionExportRecord],
) -> String {
  let lines : Array[String] = []
  if self.options.include_header() {
    let headers : Array[String] = []
    for
      field in [
        ExportTimestamp,
        ExportMetric,
        ExportValue,
        ExportBaseline,
        ExportScore,
        ExportHealth,
        ExportState,
        ExportSource,
      ] {
      headers.push(production_export_field_name(field))
    }
    lines.push(headers.join(self.options.delimiter()))
  }
  for record in records {
    lines.push(
      production_export_record_csv(record, delimiter=self.options.delimiter()),
    )
  }
  lines.join(self.options.line_ending())
}

///|
pub fn ProductionTelemetryExporter::export_prometheus(
  self : ProductionTelemetryExporter,
  records : Array[ProductionExportRecord],
) -> String {
  let lines : Array[String] = []
  let names : Array[String] = []
  for record in records {
    let name = production_export_prometheus_name(self.options, record.metric())
    if !names.contains(name) {
      names.push(name)
      lines.push("# TYPE " + name + " gauge")
    }
    lines.push(production_export_record_prometheus(record, self.options))
  }
  lines.join(self.options.line_ending())
}

///|
pub fn ProductionTelemetryExporter::export_markdown(
  self : ProductionTelemetryExporter,
  records : Array[ProductionExportRecord],
) -> String {
  let lines : Array[String] = []
  lines.push("# Telemetry export")
  lines.push("")
  lines.push(
    "| timestamp | metric | value | baseline | score | health | state | source |",
  )
  lines.push("| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |")
  for record in records {
    lines.push(production_export_record_markdown(record))
  }
  lines.join(self.options.line_ending())
}

///|
pub fn ProductionTelemetryExporter::export_summary(
  self : ProductionTelemetryExporter,
  records : Array[ProductionExportRecord],
) -> String {
  let _ = self.options.pretty()
  let mut sum = 0.0
  let mut min = 0.0
  let mut max = 0.0
  let mut health = 0.0
  if records.length() > 0 {
    min = records[0].value()
    max = records[0].value()
  }
  for record in records {
    sum = sum + record.value()
    health = health + record.health()
    if record.value() < min {
      min = record.value()
    }
    if record.value() > max {
      max = record.value()
    }
  }
  let mean = if records.length() == 0 {
    0.0
  } else {
    sum / records.length().to_double()
  }
  let average_health = if records.length() == 0 {
    1.0
  } else {
    health / records.length().to_double()
  }
  "{\"count\":" +
  records.length().to_string() +
  ",\"mean\":" +
  mean.to_string() +
  ",\"minimum\":" +
  min.to_string() +
  ",\"maximum\":" +
  max.to_string() +
  ",\"health\":" +
  average_health.to_string() +
  "}"
}

///|
pub fn ProductionTelemetryExporter::reset_stats(
  self : ProductionTelemetryExporter,
) -> Unit {
  self.stats = ProductionExportStats::new()
}

///|
/// Produce a manifest describing the selected export schema.
pub fn production_export_manifest(options : ProductionExportOptions) -> String {
  "format=" +
  production_export_format_name(options.format()) +
  " namespace=" +
  options.metric_namespace() +
  " delimiter=" +
  options.delimiter() +
  " max_records=" +
  options.max_records().to_string() +
  " fields=timestamp|metric|value|baseline|score|health|state|source"
}

///|
pub fn production_export_checksum(payload : String) -> String {
  let mut checksum = 17
  for character in payload {
    checksum = (checksum * 31 + character.to_int()) % 2147483647
  }
  checksum.to_string()
}

///|
pub fn production_export_validate_metric_name(metric : String) -> Bool {
  if metric.length() == 0 {
    false
  } else {
    let mut valid = true
    for character in metric {
      let code = character.to_int()
      if !((code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 45 ||
        code == 95 ||
        code == 46) {
        valid = false
      }
    }
    valid
  }
}

///|
pub fn production_export_normalize_metric_name(metric : String) -> String {
  let pieces : Array[String] = []
  for character in metric {
    let code = character.to_int()
    if (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      code == 95 {
      pieces.push(character.to_string())
    } else {
      pieces.push("_")
    }
  }
  let normalized = pieces.join("")
  if normalized.length() == 0 {
    "metric"
  } else {
    normalized
  }
}

///|
pub fn production_export_merge_batches(
  left : ProductionExportBatch,
  right : ProductionExportBatch,
) -> ProductionExportBatch {
  let merged = ProductionExportBatch::new(
    capacity=left.capacity() + right.capacity(),
  )
  let _ = merged.add_many(left.records())
  let _ = merged.add_many(right.records())
  merged
}

///|
pub fn production_export_group_by_metric(
  records : Array[ProductionExportRecord],
) -> Array[String] {
  let names : Array[String] = []
  for record in records {
    if !names.contains(record.metric()) {
      names.push(record.metric())
    }
  }
  names
}

///|
pub fn production_export_metric_count(
  records : Array[ProductionExportRecord],
  metric : String,
) -> Int {
  let mut count = 0
  for record in records {
    if record.metric() == metric {
      count = count + 1
    }
  }
  count
}

///|
pub fn production_export_metric_mean(
  records : Array[ProductionExportRecord],
  metric : String,
) -> Double {
  let mut sum = 0.0
  let mut count = 0
  for record in records {
    if record.metric() == metric {
      sum = sum + record.value()
      count = count + 1
    }
  }
  if count == 0 {
    0.0
  } else {
    sum / count.to_double()
  }
}
