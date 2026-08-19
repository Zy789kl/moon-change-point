///|
/// A named metric series with bounded event-time retention.
pub struct ProductionMetricSeries {
  name : String
  unit : String
  window : ProductionTimeWindow
  mut updates : Int
  mut invalid : Int
}

///|
pub fn ProductionMetricSeries::new(
  name : String,
  unit? : String = "",
  capacity? : Int = 512,
) -> ProductionMetricSeries {
  {
    name,
    unit,
    window: ProductionTimeWindow::new(capacity~),
    updates: 0,
    invalid: 0,
  }
}

///|
pub fn ProductionMetricSeries::name(self : ProductionMetricSeries) -> String {
  self.name
}

///|
pub fn ProductionMetricSeries::unit(self : ProductionMetricSeries) -> String {
  self.unit
}

///|
pub fn ProductionMetricSeries::updates(self : ProductionMetricSeries) -> Int {
  self.updates
}

///|
pub fn ProductionMetricSeries::invalid(self : ProductionMetricSeries) -> Int {
  self.invalid
}

///|
pub fn ProductionMetricSeries::push(
  self : ProductionMetricSeries,
  sample : ProductionSample,
) -> Bool {
  self.updates += 1
  if !is_finite(sample.value()) {
    self.invalid += 1
    false
  } else {
    ignore(self.window.push(sample))
    true
  }
}

///|
pub fn ProductionMetricSeries::push_point(
  self : ProductionMetricSeries,
  point : SignalPoint,
) -> Bool {
  self.push(
    ProductionSample::new(point.timestamp, point.value, sequence=point.sequence),
  )
}

///|
pub fn ProductionMetricSeries::window(
  self : ProductionMetricSeries,
) -> ProductionTimeWindow {
  self.window
}

///|
pub fn ProductionMetricSeries::values(
  self : ProductionMetricSeries,
) -> Array[Double] {
  self.window.values()
}

///|
pub fn ProductionMetricSeries::summary(
  self : ProductionMetricSeries,
) -> ProductionWindowSummary {
  self.window.summary()
}

///|
pub fn ProductionMetricSeries::latest(
  self : ProductionMetricSeries,
) -> ProductionSample? {
  self.window.last()
}

///|
pub fn ProductionMetricSeries::correlation(
  self : ProductionMetricSeries,
  other : ProductionMetricSeries,
) -> Double {
  correlation(self.values(), other.values())
}

///|
pub fn ProductionMetricSeries::change_score(
  self : ProductionMetricSeries,
  split : Int,
) -> Double {
  self.window.rolling_change(split)
}

///|
/// A deterministic collection of named series for multimetric monitoring.
pub struct ProductionMetricCatalog {
  series : Array[ProductionMetricSeries]
  mut ingested : Int
  mut rejected : Int
}

///|
pub fn ProductionMetricCatalog::new() -> ProductionMetricCatalog {
  { series: [], ingested: 0, rejected: 0 }
}

///|
pub fn ProductionMetricCatalog::register(
  self : ProductionMetricCatalog,
  metric : ProductionMetricSeries,
) -> Bool {
  for existing in self.series {
    if existing.name() == metric.name() {
      return false
    }
  }
  self.series.push(metric)
  true
}

///|
pub fn ProductionMetricCatalog::metric_count(
  self : ProductionMetricCatalog,
) -> Int {
  self.series.length()
}

///|
pub fn ProductionMetricCatalog::names(
  self : ProductionMetricCatalog,
) -> Array[String] {
  let result : Array[String] = []
  for metric in self.series {
    result.push(metric.name())
  }
  result
}

///|
pub fn ProductionMetricCatalog::find(
  self : ProductionMetricCatalog,
  name : String,
) -> ProductionMetricSeries? {
  for metric in self.series {
    if metric.name() == name {
      return Some(metric)
    }
  }
  None
}

///|
pub fn ProductionMetricCatalog::ingest(
  self : ProductionMetricCatalog,
  name : String,
  sample : ProductionSample,
) -> Bool {
  self.ingested += 1
  match self.find(name) {
    None => {
      self.rejected += 1
      false
    }
    Some(metric) => {
      let accepted = metric.push(sample)
      if !accepted {
        self.rejected += 1
      }
      accepted
    }
  }
}

///|
pub fn ProductionMetricCatalog::ingest_point(
  self : ProductionMetricCatalog,
  name : String,
  point : SignalPoint,
) -> Bool {
  self.ingest(
    name,
    ProductionSample::new(point.timestamp, point.value, sequence=point.sequence),
  )
}

///|
pub fn ProductionMetricCatalog::ingested(self : ProductionMetricCatalog) -> Int {
  self.ingested
}

///|
pub fn ProductionMetricCatalog::rejected(self : ProductionMetricCatalog) -> Int {
  self.rejected
}

///|
pub fn ProductionMetricCatalog::series(
  self : ProductionMetricCatalog,
) -> Array[ProductionMetricSeries] {
  let result : Array[ProductionMetricSeries] = []
  for metric in self.series {
    result.push(metric)
  }
  result
}

///|
/// Cross-series relation used to prioritize correlated incidents.
pub struct ProductionMetricRelation {
  left : String
  right : String
  correlation : Double
  distance : Double
  related : Bool
}

///|
pub fn ProductionMetricRelation::left(
  self : ProductionMetricRelation,
) -> String {
  self.left
}

///|
pub fn ProductionMetricRelation::right(
  self : ProductionMetricRelation,
) -> String {
  self.right
}

///|
pub fn ProductionMetricRelation::correlation(
  self : ProductionMetricRelation,
) -> Double {
  self.correlation
}

///|
pub fn ProductionMetricRelation::distance(
  self : ProductionMetricRelation,
) -> Double {
  self.distance
}

///|
pub fn ProductionMetricRelation::related(
  self : ProductionMetricRelation,
) -> Bool {
  self.related
}

///|
pub fn ProductionMetricCatalog::relations(
  self : ProductionMetricCatalog,
  correlation_threshold? : Double = 0.7,
) -> Array[ProductionMetricRelation] {
  let result : Array[ProductionMetricRelation] = []
  let threshold = if correlation_threshold < 0.0 {
    0.0
  } else {
    correlation_threshold
  }
  for i in 0..<self.series.length() {
    for j in (i + 1)..<self.series.length() {
      let left = self.series[i]
      let right = self.series[j]
      let left_values = left.values()
      let right_values = right.values()
      let relation = correlation(left_values, right_values)
      result.push({
        left: left.name(),
        right: right.name(),
        correlation: relation,
        distance: euclidean_distance(left_values, right_values),
        related: absolute(relation) >= threshold,
      })
    }
  }
  result
}

///|
/// A synchronized row across several metric series.
pub struct ProductionMetricFrame {
  timestamp : Int64
  names : Array[String]
  values : Array[Double]
  valid : Array[Bool]
}

///|
pub fn ProductionMetricFrame::new(
  timestamp : Int64,
  names : Array[String],
  values : Array[Double],
) -> ProductionMetricFrame {
  let valid : Array[Bool] = []
  for value in values {
    valid.push(is_finite(value))
  }
  { timestamp, names, values, valid }
}

///|
pub fn ProductionMetricFrame::timestamp(self : ProductionMetricFrame) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionMetricFrame::names(
  self : ProductionMetricFrame,
) -> Array[String] {
  let result : Array[String] = []
  for name in self.names {
    result.push(name)
  }
  result
}

///|
pub fn ProductionMetricFrame::values(
  self : ProductionMetricFrame,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.values {
    result.push(value)
  }
  result
}

///|
pub fn ProductionMetricFrame::valid_count(self : ProductionMetricFrame) -> Int {
  let mut count = 0
  for value in self.valid {
    if value {
      count += 1
    }
  }
  count
}

///|
pub fn ProductionMetricFrame::dimension(self : ProductionMetricFrame) -> Int {
  self.values.length()
}

///|
pub fn ProductionMetricFrame::is_complete(self : ProductionMetricFrame) -> Bool {
  self.valid_count() == self.values.length()
}

///|
/// Builds frames by joining series at the nearest timestamp within a tolerance.
pub fn production_join_series(
  series : Array[ProductionMetricSeries],
  tolerance : Int64,
) -> Array[ProductionMetricFrame] {
  let result : Array[ProductionMetricFrame] = []
  if series.length() == 0 {
    return result
  }
  let first = series[0].window().to_array()
  let names : Array[String] = []
  for metric in series {
    names.push(metric.name())
  }
  for anchor in first {
    let values : Array[Double] = [anchor.value()]
    for i in 1..<series.length() {
      let best = production_nearest_sample(
        series[i].window().to_array(),
        anchor.timestamp(),
        tolerance,
      )
      match best {
        None => values.push(0.0)
        Some(sample) => values.push(sample.value())
      }
    }
    result.push(ProductionMetricFrame::new(anchor.timestamp(), names, values))
  }
  result
}

///|
fn production_nearest_sample(
  samples : Array[ProductionSample],
  timestamp : Int64,
  tolerance : Int64,
) -> ProductionSample? {
  let mut result : ProductionSample? = None
  let mut best_distance = 9223372036854775807L
  for sample in samples {
    let distance = absolute((sample.timestamp() - timestamp).to_double()).to_int64()
    if distance <= tolerance && distance < best_distance {
      best_distance = distance
      result = Some(sample)
    }
  }
  result
}

///|
/// Computes vector-level changes over synchronized frames.
pub fn production_frame_change_score(
  before : ProductionMetricFrame,
  after : ProductionMetricFrame,
) -> Double {
  let left = before.values()
  let right = after.values()
  let n = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<n {
    total += absolute(right[i] - left[i])
  }
  total / n.to_double()
}

///|
/// A matrix of rolling metric summaries for health dashboards.
pub struct ProductionCatalogSummary {
  names : Array[String]
  means : Array[Double]
  variances : Array[Double]
  counts : Array[Int]
  quality : Array[Double]
}

///|
pub fn ProductionMetricCatalog::summary(
  self : ProductionMetricCatalog,
) -> ProductionCatalogSummary {
  let names : Array[String] = []
  let means : Array[Double] = []
  let variances : Array[Double] = []
  let counts : Array[Int] = []
  let quality : Array[Double] = []
  for metric in self.series {
    let summary = metric.summary()
    names.push(metric.name())
    means.push(summary.mean())
    variances.push(summary.variance())
    counts.push(summary.count())
    quality.push(summary.quality_ratio())
  }
  { names, means, variances, counts, quality }
}

///|
pub fn ProductionCatalogSummary::names(
  self : ProductionCatalogSummary,
) -> Array[String] {
  let result : Array[String] = []
  for name in self.names {
    result.push(name)
  }
  result
}

///|
pub fn ProductionCatalogSummary::means(
  self : ProductionCatalogSummary,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.means {
    result.push(value)
  }
  result
}

///|
pub fn ProductionCatalogSummary::variances(
  self : ProductionCatalogSummary,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.variances {
    result.push(value)
  }
  result
}

///|
pub fn ProductionCatalogSummary::counts(
  self : ProductionCatalogSummary,
) -> Array[Int] {
  let result : Array[Int] = []
  for value in self.counts {
    result.push(value)
  }
  result
}

///|
pub fn ProductionCatalogSummary::quality(
  self : ProductionCatalogSummary,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.quality {
    result.push(value)
  }
  result
}

///|
pub fn ProductionCatalogSummary::markdown(
  self : ProductionCatalogSummary,
) -> String {
  let mut output = "| metric | count | mean | variance | quality |\n|---|---:|---:|---:|---:|\n"
  for i in 0..<self.names.length() {
    output = output +
      "| " +
      self.names[i] +
      " | " +
      self.counts[i].to_string() +
      " | " +
      self.means[i].to_string() +
      " | " +
      self.variances[i].to_string() +
      " | " +
      self.quality[i].to_string() +
      " |\n"
  }
  output
}

///|
/// Aggregates multiple monitor snapshots into a fleet health score.
pub fn production_fleet_health_score(
  snapshots : Array[ProductionMonitorSnapshot],
) -> Double {
  if snapshots.length() == 0 {
    return 1.0
  }
  let mut total = 0.0
  for snapshot in snapshots {
    let state_score = match snapshot.state() {
      ColdStart => 0.5
      Healthy => 1.0
      DegradedQuality => 0.4
      AlertingState => 0.2
      RecoveringState => 0.6
      DisabledState => 0.0
    }
    total += state_score * snapshot.quality_ratio()
  }
  total / snapshots.length().to_double()
}

///|
pub fn production_fleet_health_label(score : Double) -> String {
  if score >= 0.9 {
    "healthy"
  } else if score >= 0.6 {
    "watch"
  } else {
    "at-risk"
  }
}
