///|
/// Transformation kinds available in the preprocessing chain.
pub(all) enum ProductionTransformKind {
  IdentityTransform
  ClipTransform
  DifferenceTransform
  Log1pTransform
  SqrtTransform
  ZScoreTransform
  RobustZTransform
  DetrendTransform
  SmoothTransform
  WinsorizeTransform
  SeasonalRemoveTransform
  RateTransform
}

///|
pub fn production_transform_kind_name(kind : ProductionTransformKind) -> String {
  match kind {
    IdentityTransform => "identity"
    ClipTransform => "clip"
    DifferenceTransform => "difference"
    Log1pTransform => "log1p"
    SqrtTransform => "sqrt"
    ZScoreTransform => "z-score"
    RobustZTransform => "robust-z"
    DetrendTransform => "detrend"
    SmoothTransform => "smooth"
    WinsorizeTransform => "winsorize"
    SeasonalRemoveTransform => "seasonal-remove"
    RateTransform => "rate"
  }
}

///|
/// One configured preprocessing operation.
pub struct ProductionTransformSpec {
  kind : ProductionTransformKind
  parameter_a : Double
  parameter_b : Double
  integer_parameter : Int
}

///|
pub fn ProductionTransformSpec::new(
  kind : ProductionTransformKind,
  parameter_a? : Double = 0.0,
  parameter_b? : Double = 1.0,
  integer_parameter? : Int = 3,
) -> ProductionTransformSpec {
  {
    kind,
    parameter_a,
    parameter_b,
    integer_parameter: if integer_parameter < 1 {
      1
    } else {
      integer_parameter
    },
  }
}

///|
pub fn ProductionTransformSpec::kind(
  self : ProductionTransformSpec,
) -> ProductionTransformKind {
  self.kind
}

///|
pub fn ProductionTransformSpec::parameter_a(
  self : ProductionTransformSpec,
) -> Double {
  self.parameter_a
}

///|
pub fn ProductionTransformSpec::parameter_b(
  self : ProductionTransformSpec,
) -> Double {
  self.parameter_b
}

///|
pub fn ProductionTransformSpec::integer_parameter(
  self : ProductionTransformSpec,
) -> Int {
  self.integer_parameter
}

///|
pub fn ProductionTransformSpec::summary(
  self : ProductionTransformSpec,
) -> String {
  production_transform_kind_name(self.kind) +
  "(" +
  self.parameter_a.to_string() +
  "," +
  self.parameter_b.to_string() +
  "," +
  self.integer_parameter.to_string() +
  ")"
}

///|
/// Diagnostics from one preprocessing pass.
pub struct ProductionPreprocessingReport {
  mut input_count : Int
  mut output_count : Int
  mut invalid_input : Int
  mut invalid_output : Int
  mut clipped : Int
  mut imputed : Int
  mut transformed : Int
  mut finite : Bool
}

///|
pub fn ProductionPreprocessingReport::empty() -> ProductionPreprocessingReport {
  {
    input_count: 0,
    output_count: 0,
    invalid_input: 0,
    invalid_output: 0,
    clipped: 0,
    imputed: 0,
    transformed: 0,
    finite: true,
  }
}

///|
pub fn ProductionPreprocessingReport::input_count(
  self : ProductionPreprocessingReport,
) -> Int {
  self.input_count
}

///|
pub fn ProductionPreprocessingReport::output_count(
  self : ProductionPreprocessingReport,
) -> Int {
  self.output_count
}

///|
pub fn ProductionPreprocessingReport::invalid_input(
  self : ProductionPreprocessingReport,
) -> Int {
  self.invalid_input
}

///|
pub fn ProductionPreprocessingReport::invalid_output(
  self : ProductionPreprocessingReport,
) -> Int {
  self.invalid_output
}

///|
pub fn ProductionPreprocessingReport::clipped(
  self : ProductionPreprocessingReport,
) -> Int {
  self.clipped
}

///|
pub fn ProductionPreprocessingReport::imputed(
  self : ProductionPreprocessingReport,
) -> Int {
  self.imputed
}

///|
pub fn ProductionPreprocessingReport::transformed(
  self : ProductionPreprocessingReport,
) -> Int {
  self.transformed
}

///|
pub fn ProductionPreprocessingReport::finite(
  self : ProductionPreprocessingReport,
) -> Bool {
  self.finite
}

///|
pub fn ProductionPreprocessingReport::quality(
  self : ProductionPreprocessingReport,
) -> Double {
  if self.input_count == 0 {
    1.0
  } else {
    clamp_probability(
      1.0 - self.invalid_output.to_double() / self.input_count.to_double(),
    )
  }
}

///|
pub fn ProductionPreprocessingReport::summary(
  self : ProductionPreprocessingReport,
) -> String {
  "input=" +
  self.input_count.to_string() +
  ",output=" +
  self.output_count.to_string() +
  ",invalid_input=" +
  self.invalid_input.to_string() +
  ",invalid_output=" +
  self.invalid_output.to_string() +
  ",clipped=" +
  self.clipped.to_string() +
  ",imputed=" +
  self.imputed.to_string() +
  ",transformed=" +
  self.transformed.to_string() +
  ",quality=" +
  self.quality().to_string()
}

///|
/// A transform chain that can be reused across batches.
pub struct ProductionPreprocessor {
  specs : Array[ProductionTransformSpec]
  missing : MissingValueStrategy
  mut batches : Int
  mut values : Int
  mut failed : Int
}

///|
pub fn ProductionPreprocessor::new(
  missing? : MissingValueStrategy = DropValue,
) -> ProductionPreprocessor {
  { specs: [], missing, batches: 0, values: 0, failed: 0 }
}

///|
pub fn ProductionPreprocessor::add(
  self : ProductionPreprocessor,
  spec : ProductionTransformSpec,
) -> Unit {
  self.specs.push(spec)
}

///|
pub fn ProductionPreprocessor::clear(self : ProductionPreprocessor) -> Unit {
  self.specs.clear()
}

///|
pub fn ProductionPreprocessor::specs(
  self : ProductionPreprocessor,
) -> Array[ProductionTransformSpec] {
  let result : Array[ProductionTransformSpec] = []
  for spec in self.specs {
    result.push(spec)
  }
  result
}

///|
pub fn ProductionPreprocessor::batches(self : ProductionPreprocessor) -> Int {
  self.batches
}

///|
pub fn ProductionPreprocessor::values(self : ProductionPreprocessor) -> Int {
  self.values
}

///|
pub fn ProductionPreprocessor::failed(self : ProductionPreprocessor) -> Int {
  self.failed
}

///|
fn production_safe_values(
  values : Array[Double],
  strategy : MissingValueStrategy,
) -> (Array[Double], Int) {
  let output : Array[Double] = []
  let invalid = values.length() - remove_invalid(values).length()
  let valid = remove_invalid(values)
  let fallback = match strategy {
    ImputeLast =>
      if valid.length() == 0 {
        0.0
      } else {
        valid[valid.length() - 1]
      }
    ImputeMean => mean(valid)
    ImputeZero => 0.0
    _ => 0.0
  }
  let mut last = fallback
  for value in values {
    if is_finite(value) {
      output.push(value)
      last = value
    } else {
      match strategy {
        DropValue => ()
        MarkUnknown => output.push(0.0)
        ImputeLast => output.push(last)
        ImputeMean => output.push(fallback)
        ImputeZero => output.push(0.0)
      }
    }
  }
  (output, invalid)
}

///|
fn production_transform_clip(
  values : Array[Double],
  lower : Double,
  upper : Double,
) -> (Array[Double], Int) {
  let low = if lower > upper { upper } else { lower }
  let high = if lower > upper { lower } else { upper }
  let output : Array[Double] = []
  let mut clipped = 0
  for value in values {
    let result = if value < low {
      clipped += 1
      low
    } else if value > high {
      clipped += 1
      high
    } else {
      value
    }
    output.push(result)
  }
  (output, clipped)
}

///|
fn production_transform_difference(
  values : Array[Double],
  lag : Int,
) -> Array[Double] {
  let output : Array[Double] = []
  let safe_lag = if lag < 1 { 1 } else { lag }
  for i in safe_lag..<values.length() {
    output.push(values[i] - values[i - safe_lag])
  }
  output
}

///|
fn production_transform_log1p(values : Array[Double]) -> Array[Double] {
  let output : Array[Double] = []
  for value in values {
    let safe = if value <= -1.0 { -0.999999999999 } else { value }
    output.push(@math.ln(1.0 + safe))
  }
  output
}

///|
fn production_transform_sqrt(values : Array[Double]) -> Array[Double] {
  let output : Array[Double] = []
  for value in values {
    output.push(if value < 0.0 { 0.0 } else { value.sqrt() })
  }
  output
}

///|
fn production_transform_zscore(values : Array[Double]) -> Array[Double] {
  let center = mean(values)
  let scale = standard_deviation(values)
  let safe_scale = if scale < 1.0e-12 { 1.0 } else { scale }
  let output : Array[Double] = []
  for value in values {
    output.push((value - center) / safe_scale)
  }
  output
}

///|
fn production_transform_robust_z(values : Array[Double]) -> Array[Double] {
  let center = median(values)
  let scale = median_absolute_deviation(values)
  let safe_scale = if scale < 1.0e-12 { 1.0 } else { scale }
  let output : Array[Double] = []
  for value in values {
    output.push((value - center) / safe_scale)
  }
  output
}

///|
fn production_transform_detrend(values : Array[Double]) -> Array[Double] {
  let slope = linear_slope(values)
  let center = mean(values)
  let output : Array[Double] = []
  for i, value in values {
    output.push(
      value -
      (
        center +
        slope * (i.to_double() - (values.length() - 1).to_double() / 2.0)
      ),
    )
  }
  output
}

///|
fn production_transform_smooth(
  values : Array[Double],
  width : Int,
) -> Array[Double] {
  let safe_width = if width < 1 { 1 } else { width }
  let output : Array[Double] = []
  for i in 0..<values.length() {
    let start = if i + 1 < safe_width { 0 } else { i + 1 - safe_width }
    let sample : Array[Double] = []
    for j in start..<=i {
      sample.push(values[j])
    }
    output.push(mean(sample))
  }
  output
}

///|
fn production_transform_winsorize(
  values : Array[Double],
  lower_probability : Double,
  upper_probability : Double,
) -> Array[Double] {
  let lower = quantile(values, lower_probability)
  let upper = quantile(values, upper_probability)
  production_transform_clip(values, lower, upper).0
}

///|
fn production_transform_seasonal_remove(
  values : Array[Double],
  period : Int,
) -> Array[Double] {
  if period < 2 || values.length() < period {
    return values
  }
  deseasonalize(values, period)
}

///|
fn production_transform_rate(values : Array[Double]) -> Array[Double] {
  production_percent_changes(values)
}

///|
fn production_apply_spec(
  values : Array[Double],
  spec : ProductionTransformSpec,
) -> (Array[Double], Int) {
  match spec.kind() {
    IdentityTransform => (values, 0)
    ClipTransform =>
      production_transform_clip(values, spec.parameter_a(), spec.parameter_b()).0
      |> fn(result) { (result, 0) }
    DifferenceTransform =>
      (production_transform_difference(values, spec.integer_parameter()), 0)
    Log1pTransform => (production_transform_log1p(values), 0)
    SqrtTransform => (production_transform_sqrt(values), 0)
    ZScoreTransform => (production_transform_zscore(values), 0)
    RobustZTransform => (production_transform_robust_z(values), 0)
    DetrendTransform => (production_transform_detrend(values), 0)
    SmoothTransform =>
      (production_transform_smooth(values, spec.integer_parameter()), 0)
    WinsorizeTransform =>
      (
        production_transform_winsorize(
          values,
          spec.parameter_a(),
          spec.parameter_b(),
        ),
        0,
      )
    SeasonalRemoveTransform =>
      (
        production_transform_seasonal_remove(values, spec.integer_parameter()),
        0,
      )
    RateTransform => (production_transform_rate(values), 0)
  }
}

///|
pub fn ProductionPreprocessor::transform(
  self : ProductionPreprocessor,
  values : Array[Double],
) -> (Array[Double], ProductionPreprocessingReport) {
  let safe = production_safe_values(values, self.missing)
  let mut current = safe.0
  let report = ProductionPreprocessingReport::empty()
  report.input_count = values.length()
  report.invalid_input = safe.1
  report.imputed = if self.missing is DropValue { 0 } else { safe.1 }
  let mut transformed = 0
  let mut clipped = 0
  for spec in self.specs {
    let next = production_apply_spec(current, spec)
    current = next.0
    clipped += next.1
    transformed += 1
  }
  report.output_count = current.length()
  report.clipped = clipped
  report.transformed = transformed
  report.invalid_output = current.length() - remove_invalid(current).length()
  report.finite = report.invalid_output == 0
  self.batches += 1
  self.values += values.length()
  if !report.finite {
    self.failed += 1
  }
  (current, report)
}

///|
pub fn ProductionPreprocessor::transform_points(
  self : ProductionPreprocessor,
  points : Array[SignalPoint],
) -> (Array[SignalPoint], ProductionPreprocessingReport) {
  let values : Array[Double] = []
  for point in points {
    values.push(point.value)
  }
  let transformed = self.transform(values)
  let output : Array[SignalPoint] = []
  let n = if transformed.0.length() < points.length() {
    transformed.0.length()
  } else {
    points.length()
  }
  for i in 0..<n {
    output.push(
      SignalPoint::new(
        points[i].timestamp,
        transformed.0[i],
        sequence=points[i].sequence,
      ),
    )
  }
  (output, transformed.1)
}

///|
pub fn ProductionPreprocessor::transform_batches(
  self : ProductionPreprocessor,
  batches : Array[Array[Double]],
) -> Array[Array[Double]] {
  let result : Array[Array[Double]] = []
  for batch in batches {
    result.push(self.transform(batch).0)
  }
  result
}

///|
pub fn production_transform_values(
  values : Array[Double],
  specs : Array[ProductionTransformSpec],
  missing? : MissingValueStrategy = DropValue,
) -> Array[Double] {
  let preprocessor = ProductionPreprocessor::new(missing~)
  for spec in specs {
    preprocessor.add(spec)
  }
  preprocessor.transform(values).0
}

///|
pub fn production_clip_percentiles(
  values : Array[Double],
  lower? : Double = 0.01,
  upper? : Double = 0.99,
) -> Array[Double] {
  production_transform_winsorize(
    values,
    clamp_probability(lower),
    clamp_probability(upper),
  )
}

///|
pub fn production_normalize_range(
  values : Array[Double],
  lower? : Double = 0.0,
  upper? : Double = 1.0,
) -> Array[Double] {
  if values.length() == 0 {
    return []
  }
  let source_low = array_minimum(values)
  let source_high = array_maximum(values)
  if source_high <= source_low {
    return Array::make(values.length(), lower)
  }
  let result : Array[Double] = []
  for value in values {
    result.push(
      lower +
      (value - source_low) * (upper - lower) / (source_high - source_low),
    )
  }
  result
}

///|
pub fn production_center_scale(values : Array[Double]) -> Array[Double] {
  production_transform_robust_z(values)
}

///|
pub fn production_residuals_from_trend(values : Array[Double]) -> Array[Double] {
  production_transform_detrend(values)
}

///|
pub fn production_smoothed_values(
  values : Array[Double],
  width? : Int = 5,
) -> Array[Double] {
  production_transform_smooth(values, width)
}
