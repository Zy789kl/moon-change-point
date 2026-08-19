///|
/// Runtime data types accepted by a production change-point pipeline.
pub(all) enum ProductionContractFieldKind {
  Numeric
  Timestamp
  Sequence
  Label
  Boolean
}

///|
pub fn production_contract_field_kind_name(
  kind : ProductionContractFieldKind,
) -> String {
  match kind {
    Numeric => "numeric"
    Timestamp => "timestamp"
    Sequence => "sequence"
    Label => "label"
    Boolean => "boolean"
  }
}

///|
/// Validation severity used by a data contract.
pub(all) enum ProductionContractSeverity {
  ContractError
  ContractWarning
}

///|
pub fn production_contract_severity_name(
  severity : ProductionContractSeverity,
) -> String {
  match severity {
    ContractError => "error"
    ContractWarning => "warning"
  }
}

///|
/// Machine-readable reason for rejecting or downgrading an observation.
pub(all) enum ProductionContractViolationCode {
  MissingMetric
  MissingValue
  NonFiniteValue
  ValueBelowMinimum
  ValueAboveMaximum
  TimestampOutOfOrder
  TimestampTooOld
  DuplicateSequence
  EmptyLabel
  LabelTooLong
  InvalidBoolean
  InsufficientSamples
  ExcessiveGap
  CardinalityExceeded
  SchemaMismatch
}

///|
pub fn production_contract_violation_code_name(
  code : ProductionContractViolationCode,
) -> String {
  match code {
    MissingMetric => "missing-metric"
    MissingValue => "missing-value"
    NonFiniteValue => "non-finite-value"
    ValueBelowMinimum => "below-minimum"
    ValueAboveMaximum => "above-maximum"
    TimestampOutOfOrder => "timestamp-out-of-order"
    TimestampTooOld => "timestamp-too-old"
    DuplicateSequence => "duplicate-sequence"
    EmptyLabel => "empty-label"
    LabelTooLong => "label-too-long"
    InvalidBoolean => "invalid-boolean"
    InsufficientSamples => "insufficient-samples"
    ExcessiveGap => "excessive-gap"
    CardinalityExceeded => "cardinality-exceeded"
    SchemaMismatch => "schema-mismatch"
  }
}

///|
/// Declarative validation rules for a metric stream.
pub struct ProductionContractRule {
  name : String
  field_kind : ProductionContractFieldKind
  required : Bool
  allow_missing : Bool
  minimum : Double
  maximum : Double
  has_minimum : Bool
  has_maximum : Bool
  minimum_samples : Int
  maximum_gap : Int64
  monotonic_timestamps : Bool
  maximum_label_length : Int
  maximum_distinct_values : Int
  severity : ProductionContractSeverity
}

///|
pub fn ProductionContractRule::new(
  name : String,
  field_kind? : ProductionContractFieldKind = Numeric,
  required? : Bool = true,
  allow_missing? : Bool = false,
  minimum? : Double = 0.0,
  maximum? : Double = 0.0,
  has_minimum? : Bool = false,
  has_maximum? : Bool = false,
  minimum_samples? : Int = 1,
  maximum_gap? : Int64 = 0L,
  monotonic_timestamps? : Bool = true,
  maximum_label_length? : Int = 128,
  maximum_distinct_values? : Int = 1000,
  severity? : ProductionContractSeverity = ContractError,
) -> ProductionContractRule {
  {
    name,
    field_kind,
    required,
    allow_missing,
    minimum,
    maximum,
    has_minimum,
    has_maximum,
    minimum_samples: if minimum_samples < 1 {
      1
    } else {
      minimum_samples
    },
    maximum_gap: if maximum_gap < 0L {
      0L
    } else {
      maximum_gap
    },
    monotonic_timestamps,
    maximum_label_length: if maximum_label_length < 1 {
      1
    } else {
      maximum_label_length
    },
    maximum_distinct_values: if maximum_distinct_values < 1 {
      1
    } else {
      maximum_distinct_values
    },
    severity,
  }
}

///|
pub fn ProductionContractRule::name(self : ProductionContractRule) -> String {
  self.name
}

///|
pub fn ProductionContractRule::field_kind(
  self : ProductionContractRule,
) -> ProductionContractFieldKind {
  self.field_kind
}

///|
pub fn ProductionContractRule::required(self : ProductionContractRule) -> Bool {
  self.required
}

///|
pub fn ProductionContractRule::allow_missing(
  self : ProductionContractRule,
) -> Bool {
  self.allow_missing
}

///|
pub fn ProductionContractRule::minimum(self : ProductionContractRule) -> Double {
  self.minimum
}

///|
pub fn ProductionContractRule::maximum(self : ProductionContractRule) -> Double {
  self.maximum
}

///|
pub fn ProductionContractRule::has_minimum(
  self : ProductionContractRule,
) -> Bool {
  self.has_minimum
}

///|
pub fn ProductionContractRule::has_maximum(
  self : ProductionContractRule,
) -> Bool {
  self.has_maximum
}

///|
pub fn ProductionContractRule::minimum_samples(
  self : ProductionContractRule,
) -> Int {
  self.minimum_samples
}

///|
pub fn ProductionContractRule::maximum_gap(
  self : ProductionContractRule,
) -> Int64 {
  self.maximum_gap
}

///|
pub fn ProductionContractRule::monotonic_timestamps(
  self : ProductionContractRule,
) -> Bool {
  self.monotonic_timestamps
}

///|
pub fn ProductionContractRule::maximum_label_length(
  self : ProductionContractRule,
) -> Int {
  self.maximum_label_length
}

///|
pub fn ProductionContractRule::maximum_distinct_values(
  self : ProductionContractRule,
) -> Int {
  self.maximum_distinct_values
}

///|
pub fn ProductionContractRule::severity(
  self : ProductionContractRule,
) -> ProductionContractSeverity {
  self.severity
}

///|
/// One contract violation retained for audit and diagnostics.
pub struct ProductionContractViolation {
  code : ProductionContractViolationCode
  severity : ProductionContractSeverity
  metric : String
  rule : String
  index : Int
  value : Double
  has_value : Bool
  message : String
}

///|
pub fn ProductionContractViolation::new(
  code : ProductionContractViolationCode,
  severity : ProductionContractSeverity,
  metric : String,
  rule : String,
  index? : Int = -1,
  value? : Double = 0.0,
  has_value? : Bool = false,
  message? : String = "",
) -> ProductionContractViolation {
  { code, severity, metric, rule, index, value, has_value, message }
}

///|
pub fn ProductionContractViolation::code(
  self : ProductionContractViolation,
) -> ProductionContractViolationCode {
  self.code
}

///|
pub fn ProductionContractViolation::severity(
  self : ProductionContractViolation,
) -> ProductionContractSeverity {
  self.severity
}

///|
pub fn ProductionContractViolation::metric(
  self : ProductionContractViolation,
) -> String {
  self.metric
}

///|
pub fn ProductionContractViolation::rule(
  self : ProductionContractViolation,
) -> String {
  self.rule
}

///|
pub fn ProductionContractViolation::index(
  self : ProductionContractViolation,
) -> Int {
  self.index
}

///|
pub fn ProductionContractViolation::has_value(
  self : ProductionContractViolation,
) -> Bool {
  self.has_value
}

///|
pub fn ProductionContractViolation::value(
  self : ProductionContractViolation,
) -> Double {
  self.value
}

///|
pub fn ProductionContractViolation::message(
  self : ProductionContractViolation,
) -> String {
  self.message
}

///|
pub fn ProductionContractViolation::summary(
  self : ProductionContractViolation,
) -> String {
  let location = if self.index < 0 {
    "stream"
  } else {
    "sample[" + self.index.to_string() + "]"
  }
  let value_text = if self.has_value {
    " value=" + self.value.to_string()
  } else {
    ""
  }
  production_contract_severity_name(self.severity) +
  " " +
  self.metric +
  " " +
  location +
  " " +
  production_contract_violation_code_name(self.code) +
  value_text +
  " " +
  self.message
}

///|
/// Result of validating one metric stream.
pub struct ProductionContractReport {
  metric : String
  mut checked : Int
  mut accepted : Int
  mut rejected : Int
  missing : Int
  mut warnings : Int
  violations : Array[ProductionContractViolation]
  distinct_labels : Array[String]
  mut first_timestamp : Int64
  mut last_timestamp : Int64
  mut has_timestamp : Bool
  mut monotonic : Bool
}

///|
pub fn ProductionContractReport::new(
  metric : String,
) -> ProductionContractReport {
  {
    metric,
    checked: 0,
    accepted: 0,
    rejected: 0,
    missing: 0,
    warnings: 0,
    violations: [],
    distinct_labels: [],
    first_timestamp: 0L,
    last_timestamp: 0L,
    has_timestamp: false,
    monotonic: true,
  }
}

///|
pub fn ProductionContractReport::metric(
  self : ProductionContractReport,
) -> String {
  self.metric
}

///|
pub fn ProductionContractReport::checked(
  self : ProductionContractReport,
) -> Int {
  self.checked
}

///|
pub fn ProductionContractReport::accepted(
  self : ProductionContractReport,
) -> Int {
  self.accepted
}

///|
pub fn ProductionContractReport::rejected(
  self : ProductionContractReport,
) -> Int {
  self.rejected
}

///|
pub fn ProductionContractReport::missing(
  self : ProductionContractReport,
) -> Int {
  self.missing
}

///|
pub fn ProductionContractReport::warnings(
  self : ProductionContractReport,
) -> Int {
  self.warnings
}

///|
pub fn ProductionContractReport::violations(
  self : ProductionContractReport,
) -> Array[ProductionContractViolation] {
  self.violations[:].to_owned()
}

///|
pub fn ProductionContractReport::distinct_count(
  self : ProductionContractReport,
) -> Int {
  self.distinct_labels.length()
}

///|
pub fn ProductionContractReport::first_timestamp(
  self : ProductionContractReport,
) -> Int64 {
  self.first_timestamp
}

///|
pub fn ProductionContractReport::last_timestamp(
  self : ProductionContractReport,
) -> Int64 {
  self.last_timestamp
}

///|
pub fn ProductionContractReport::monotonic(
  self : ProductionContractReport,
) -> Bool {
  self.monotonic
}

///|
pub fn ProductionContractReport::acceptance_rate(
  self : ProductionContractReport,
) -> Double {
  if self.checked == 0 {
    1.0
  } else {
    self.accepted.to_double() / self.checked.to_double()
  }
}

///|
pub fn ProductionContractReport::is_valid(
  self : ProductionContractReport,
) -> Bool {
  self.rejected == 0 && self.accepted >= 0
}

///|
pub fn ProductionContractReport::summary(
  self : ProductionContractReport,
) -> String {
  self.metric +
  " checked=" +
  self.checked.to_string() +
  " accepted=" +
  self.accepted.to_string() +
  " rejected=" +
  self.rejected.to_string() +
  " missing=" +
  self.missing.to_string() +
  " warnings=" +
  self.warnings.to_string() +
  " rate=" +
  self.acceptance_rate().to_string()
}

///|
/// A compact contract snapshot suitable for health endpoints.
pub struct ProductionContractSummary {
  contract_count : Int
  report_count : Int
  valid_count : Int
  rejected_count : Int
  warning_count : Int
  total_samples : Int
  total_violations : Int
}

///|
pub fn ProductionContractSummary::contract_count(
  self : ProductionContractSummary,
) -> Int {
  self.contract_count
}

///|
pub fn ProductionContractSummary::report_count(
  self : ProductionContractSummary,
) -> Int {
  self.report_count
}

///|
pub fn ProductionContractSummary::valid_count(
  self : ProductionContractSummary,
) -> Int {
  self.valid_count
}

///|
pub fn ProductionContractSummary::rejected_count(
  self : ProductionContractSummary,
) -> Int {
  self.rejected_count
}

///|
pub fn ProductionContractSummary::warning_count(
  self : ProductionContractSummary,
) -> Int {
  self.warning_count
}

///|
pub fn ProductionContractSummary::total_samples(
  self : ProductionContractSummary,
) -> Int {
  self.total_samples
}

///|
pub fn ProductionContractSummary::total_violations(
  self : ProductionContractSummary,
) -> Int {
  self.total_violations
}

///|
pub fn ProductionContractSummary::health_score(
  self : ProductionContractSummary,
) -> Double {
  if self.total_samples == 0 {
    1.0
  } else {
    let failures = self.rejected_count.to_double()
    let samples = self.total_samples.to_double()
    clamp_probability(1.0 - failures / samples)
  }
}

///|
/// Runtime validator for metric contracts. Rules stay in memory so a service
/// can validate every batch without rebuilding schema state.
pub struct ProductionContractValidator {
  mut rules : Array[ProductionContractRule]
  mut reports : Array[ProductionContractReport]
  mut total_batches : Int
  mut total_samples : Int
  mut total_violations : Int
}

///|
pub fn ProductionContractValidator::new() -> ProductionContractValidator {
  {
    rules: [],
    reports: [],
    total_batches: 0,
    total_samples: 0,
    total_violations: 0,
  }
}

///|
fn production_contract_index_of(
  rules : Array[ProductionContractRule],
  name : String,
) -> Int {
  for i = 0; i < rules.length(); i = i + 1 {
    if rules[i].name() == name {
      return i
    }
  }
  -1
}

///|
pub fn ProductionContractValidator::register(
  self : ProductionContractValidator,
  rule : ProductionContractRule,
) -> Bool {
  let index = production_contract_index_of(self.rules, rule.name())
  if index < 0 {
    self.rules.push(rule)
    true
  } else {
    self.rules[index] = rule
    false
  }
}

///|
pub fn ProductionContractValidator::remove(
  self : ProductionContractValidator,
  name : String,
) -> Bool {
  let index = production_contract_index_of(self.rules, name)
  if index < 0 {
    false
  } else {
    let remaining : Array[ProductionContractRule] = []
    for i = 0; i < self.rules.length(); i = i + 1 {
      if i != index {
        remaining.push(self.rules[i])
      }
    }
    self.rules = remaining
    true
  }
}

///|
pub fn ProductionContractValidator::rule_count(
  self : ProductionContractValidator,
) -> Int {
  self.rules.length()
}

///|
pub fn ProductionContractValidator::rules(
  self : ProductionContractValidator,
) -> Array[ProductionContractRule] {
  self.rules[:].to_owned()
}

///|
pub fn ProductionContractValidator::reports(
  self : ProductionContractValidator,
) -> Array[ProductionContractReport] {
  self.reports[:].to_owned()
}

///|
pub fn ProductionContractValidator::total_batches(
  self : ProductionContractValidator,
) -> Int {
  self.total_batches
}

///|
pub fn ProductionContractValidator::total_samples(
  self : ProductionContractValidator,
) -> Int {
  self.total_samples
}

///|
pub fn ProductionContractValidator::total_violations(
  self : ProductionContractValidator,
) -> Int {
  self.total_violations
}

///|
fn production_contract_violation_is_warning(
  violation : ProductionContractViolation,
) -> Bool {
  violation.severity() is ContractWarning
}

///|
fn production_contract_contains_label(
  labels : Array[String],
  label : String,
) -> Bool {
  for item in labels {
    if item == label {
      return true
    }
  }
  false
}

///|
fn production_contract_push_violation(
  report : ProductionContractReport,
  violation : ProductionContractViolation,
) -> Unit {
  report.violations.push(violation)
  if production_contract_violation_is_warning(violation) {
    report.warnings = report.warnings + 1
  } else {
    report.rejected = report.rejected + 1
  }
}

///|
fn production_contract_is_finite(value : Double) -> Bool {
  value == value && value > -1.0e308 && value < 1.0e308
}

///|
fn production_contract_validate_numeric(
  rule : ProductionContractRule,
  report : ProductionContractReport,
  index : Int,
  value : Double,
) -> Bool {
  let mut valid = true
  if !production_contract_is_finite(value) {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        NonFiniteValue,
        rule.severity(),
        rule.name(),
        rule.name(),
        index~,
        value~,
        has_value=true,
        message="numeric value is not finite",
      ),
    )
    valid = false
  }
  if rule.has_minimum() && value < rule.minimum() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        ValueBelowMinimum,
        rule.severity(),
        rule.name(),
        rule.name(),
        index~,
        value~,
        has_value=true,
        message="value is below the contract minimum",
      ),
    )
    valid = false
  }
  if rule.has_maximum() && value > rule.maximum() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        ValueAboveMaximum,
        rule.severity(),
        rule.name(),
        rule.name(),
        index~,
        value~,
        has_value=true,
        message="value is above the contract maximum",
      ),
    )
    valid = false
  }
  valid
}

///|
fn production_contract_validate_labels(
  rule : ProductionContractRule,
  report : ProductionContractReport,
  index : Int,
  label : String,
) -> Bool {
  let mut valid = true
  if label.length() == 0 {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        EmptyLabel,
        rule.severity(),
        rule.name(),
        rule.name(),
        index~,
        message="label must not be empty",
      ),
    )
    valid = false
  }
  if label.length() > rule.maximum_label_length() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        LabelTooLong,
        rule.severity(),
        rule.name(),
        rule.name(),
        index~,
        message="label exceeds the configured length",
      ),
    )
    valid = false
  }
  if !production_contract_contains_label(report.distinct_labels, label) {
    report.distinct_labels.push(label)
  }
  if report.distinct_labels.length() > rule.maximum_distinct_values() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        CardinalityExceeded,
        rule.severity(),
        rule.name(),
        rule.name(),
        index~,
        message="label cardinality exceeds the configured limit",
      ),
    )
    valid = false
  }
  valid
}

///|
fn production_contract_update_timestamp(
  rule : ProductionContractRule,
  report : ProductionContractReport,
  index : Int,
  timestamp : Int64,
) -> Bool {
  let mut valid = true
  if report.has_timestamp {
    if timestamp < report.last_timestamp {
      report.monotonic = false
      if rule.monotonic_timestamps() {
        production_contract_push_violation(
          report,
          ProductionContractViolation::new(
            TimestampOutOfOrder,
            rule.severity(),
            rule.name(),
            rule.name(),
            index~,
            message="timestamps must be monotonic",
          ),
        )
        valid = false
      }
    }
    if rule.maximum_gap() > 0L &&
      timestamp - report.last_timestamp > rule.maximum_gap() {
      production_contract_push_violation(
        report,
        ProductionContractViolation::new(
          ExcessiveGap,
          rule.severity(),
          rule.name(),
          rule.name(),
          index~,
          message="timestamp gap exceeds the contract",
        ),
      )
      valid = false
    }
  } else {
    report.first_timestamp = timestamp
    report.has_timestamp = true
  }
  if timestamp > report.last_timestamp || !report.has_timestamp {
    report.last_timestamp = timestamp
  }
  valid
}

///|
/// Validate numeric samples and event-time ordering for one metric batch.
pub fn ProductionContractValidator::validate_numeric_batch(
  self : ProductionContractValidator,
  metric : String,
  timestamps : Array[Int64],
  values : Array[Double],
) -> ProductionContractReport {
  let rule_index = production_contract_index_of(self.rules, metric)
  let rule = if rule_index < 0 {
    ProductionContractRule::new(metric, required=false, allow_missing=true)
  } else {
    self.rules[rule_index]
  }
  let report = ProductionContractReport::new(metric)
  let count = if timestamps.length() < values.length() {
    timestamps.length()
  } else {
    values.length()
  }
  self.total_batches = self.total_batches + 1
  self.total_samples = self.total_samples + count
  for i = 0; i < count; i = i + 1 {
    report.checked = report.checked + 1
    let time_valid = production_contract_update_timestamp(
      rule,
      report,
      i,
      timestamps[i],
    )
    let value_valid = production_contract_validate_numeric(
      rule,
      report,
      i,
      values[i],
    )
    if time_valid && value_valid {
      report.accepted = report.accepted + 1
    }
  }
  if timestamps.length() != values.length() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        SchemaMismatch,
        ContractError,
        metric,
        metric,
        message="timestamps and values have different lengths",
      ),
    )
  }
  if report.checked < rule.minimum_samples() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        InsufficientSamples,
        rule.severity(),
        metric,
        metric,
        message="batch contains fewer samples than required",
      ),
    )
  }
  self.total_violations = self.total_violations + report.violations.length()
  self.reports.push(report)
  report
}

///|
/// Validate categorical labels while tracking bounded cardinality.
pub fn ProductionContractValidator::validate_label_batch(
  self : ProductionContractValidator,
  metric : String,
  timestamps : Array[Int64],
  labels : Array[String],
) -> ProductionContractReport {
  let rule_index = production_contract_index_of(self.rules, metric)
  let rule = if rule_index < 0 {
    ProductionContractRule::new(
      metric,
      field_kind=Label,
      required=false,
      allow_missing=true,
    )
  } else {
    self.rules[rule_index]
  }
  let report = ProductionContractReport::new(metric)
  let count = if timestamps.length() < labels.length() {
    timestamps.length()
  } else {
    labels.length()
  }
  self.total_batches = self.total_batches + 1
  self.total_samples = self.total_samples + count
  for i = 0; i < count; i = i + 1 {
    report.checked = report.checked + 1
    let time_valid = production_contract_update_timestamp(
      rule,
      report,
      i,
      timestamps[i],
    )
    let label_valid = production_contract_validate_labels(
      rule,
      report,
      i,
      labels[i],
    )
    if time_valid && label_valid {
      report.accepted = report.accepted + 1
    }
  }
  if timestamps.length() != labels.length() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        SchemaMismatch,
        ContractError,
        metric,
        metric,
        message="timestamps and labels have different lengths",
      ),
    )
  }
  if report.checked < rule.minimum_samples() {
    production_contract_push_violation(
      report,
      ProductionContractViolation::new(
        InsufficientSamples,
        rule.severity(),
        metric,
        metric,
        message="batch contains fewer labels than required",
      ),
    )
  }
  self.total_violations = self.total_violations + report.violations.length()
  self.reports.push(report)
  report
}

///|
/// Validate a batch and return only the samples accepted by the contract.
pub fn ProductionContractValidator::filter_numeric_batch(
  self : ProductionContractValidator,
  metric : String,
  timestamps : Array[Int64],
  values : Array[Double],
) -> (Array[Int64], Array[Double], ProductionContractReport) {
  let report = self.validate_numeric_batch(metric, timestamps, values)
  let accepted_times : Array[Int64] = []
  let accepted_values : Array[Double] = []
  let rule_index = production_contract_index_of(self.rules, report.metric())
  let rule = if rule_index < 0 {
    ProductionContractRule::new(
      report.metric(),
      required=false,
      allow_missing=true,
    )
  } else {
    self.rules[rule_index]
  }
  let count = if timestamps.length() < values.length() {
    timestamps.length()
  } else {
    values.length()
  }
  for i = 0; i < count; i = i + 1 {
    let numeric_ok = production_contract_is_finite(values[i]) &&
      (!rule.has_minimum() || values[i] >= rule.minimum()) &&
      (!rule.has_maximum() || values[i] <= rule.maximum())
    if numeric_ok {
      accepted_times.push(timestamps[i])
      accepted_values.push(values[i])
    }
  }
  (accepted_times, accepted_values, report)
}

///|
pub fn ProductionContractValidator::latest_report(
  self : ProductionContractValidator,
) -> ProductionContractReport? {
  if self.reports.length() == 0 {
    None
  } else {
    Some(self.reports[self.reports.length() - 1])
  }
}

///|
pub fn ProductionContractValidator::summary(
  self : ProductionContractValidator,
) -> ProductionContractSummary {
  let mut valid_count = 0
  let mut rejected_count = 0
  let mut warning_count = 0
  let mut violations = 0
  for report in self.reports {
    if report.is_valid() {
      valid_count = valid_count + 1
    }
    rejected_count = rejected_count + report.rejected()
    warning_count = warning_count + report.warnings()
    violations = violations + report.violations.length()
  }
  {
    contract_count: self.rules.length(),
    report_count: self.reports.length(),
    valid_count,
    rejected_count,
    warning_count,
    total_samples: self.total_samples,
    total_violations: violations,
  }
}

///|
pub fn ProductionContractValidator::clear_reports(
  self : ProductionContractValidator,
) -> Unit {
  self.reports = []
  self.total_batches = 0
  self.total_samples = 0
  self.total_violations = 0
}

///|
/// Returns whether a timestamp series is non-decreasing.
pub fn production_validate_monotonic_timestamps(
  timestamps : Array[Int64],
) -> Bool {
  if timestamps.length() < 2 {
    true
  } else {
    for i = 1; i < timestamps.length(); i = i + 1 {
      if timestamps[i] < timestamps[i - 1] {
        return false
      }
    }
    true
  }
}

///|
/// Returns the largest time gap in a timestamp series.
pub fn production_contract_largest_gap(timestamps : Array[Int64]) -> Int64 {
  let mut largest = 0L
  if timestamps.length() > 1 {
    for i = 1; i < timestamps.length(); i = i + 1 {
      let gap = timestamps[i] - timestamps[i - 1]
      if gap > largest {
        largest = gap
      }
    }
  }
  largest
}

///|
pub fn production_contract_distinct_labels(labels : Array[String]) -> Int {
  let distinct : Array[String] = []
  for label in labels {
    if !production_contract_contains_label(distinct, label) {
      distinct.push(label)
    }
  }
  distinct.length()
}

///|
/// Stable, order-sensitive checksum for a contract definition.
pub fn production_contract_checksum(rule : ProductionContractRule) -> String {
  let seed = rule.name().length().to_string() +
    ":" +
    production_contract_field_kind_name(rule.field_kind()) +
    ":" +
    rule.minimum_samples().to_string() +
    ":" +
    rule.maximum_gap().to_string() +
    ":" +
    rule.maximum_label_length().to_string() +
    ":" +
    rule.maximum_distinct_values().to_string()
  let mut hash = 216613626
  for character in seed {
    hash = (hash * 16777619 + character.to_int()) % 2147483647
  }
  hash.to_string()
}

///|
pub fn production_contract_report_json(
  report : ProductionContractReport,
) -> String {
  let monotonic_text = if report.monotonic() { "true" } else { "false" }
  "{\"metric\":\"" +
  report.metric() +
  "\",\"checked\":" +
  report.checked().to_string() +
  ",\"accepted\":" +
  report.accepted().to_string() +
  ",\"rejected\":" +
  report.rejected().to_string() +
  ",\"warnings\":" +
  report.warnings().to_string() +
  ",\"monotonic\":" +
  monotonic_text +
  "}"
}

///|
pub fn production_contract_summary_markdown(
  summary : ProductionContractSummary,
) -> String {
  "| contracts | reports | samples | rejected | warnings | health |\n" +
  "| ---: | ---: | ---: | ---: | ---: | ---: |\n" +
  "| " +
  summary.contract_count().to_string() +
  " | " +
  summary.report_count().to_string() +
  " | " +
  summary.total_samples().to_string() +
  " | " +
  summary.rejected_count().to_string() +
  " | " +
  summary.warning_count().to_string() +
  " | " +
  summary.health_score().to_string() +
  " |"
}
