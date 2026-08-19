///|
/// A validated sample entering a production analytics pipeline.
pub struct ProductionSample {
  timestamp : Int64
  value : Double
  sequence : Int
  imputed : Bool
  late : Bool
}

///|
pub fn ProductionSample::new(
  timestamp : Int64,
  value : Double,
  sequence? : Int = 0,
  imputed? : Bool = false,
  late? : Bool = false,
) -> ProductionSample {
  { timestamp, value, sequence, imputed, late }
}

///|
pub fn ProductionSample::timestamp(self : ProductionSample) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionSample::value(self : ProductionSample) -> Double {
  self.value
}

///|
pub fn ProductionSample::sequence(self : ProductionSample) -> Int {
  self.sequence
}

///|
pub fn ProductionSample::imputed(self : ProductionSample) -> Bool {
  self.imputed
}

///|
pub fn ProductionSample::late(self : ProductionSample) -> Bool {
  self.late
}

///|
/// Aggregation statistics for a bounded event-time window.
pub struct ProductionWindowSummary {
  start_timestamp : Int64
  end_timestamp : Int64
  count : Int
  valid_count : Int
  imputed_count : Int
  late_count : Int
  sum : Double
  mean : Double
  variance : Double
  minimum : Double
  maximum : Double
  median : Double
  first : Double
  last : Double
}

///|
pub fn ProductionWindowSummary::empty() -> ProductionWindowSummary {
  {
    start_timestamp: 0L,
    end_timestamp: 0L,
    count: 0,
    valid_count: 0,
    imputed_count: 0,
    late_count: 0,
    sum: 0.0,
    mean: 0.0,
    variance: 0.0,
    minimum: 0.0,
    maximum: 0.0,
    median: 0.0,
    first: 0.0,
    last: 0.0,
  }
}

///|
pub fn ProductionWindowSummary::start(self : ProductionWindowSummary) -> Int64 {
  self.start_timestamp
}

///|
pub fn ProductionWindowSummary::end(self : ProductionWindowSummary) -> Int64 {
  self.end_timestamp
}

///|
pub fn ProductionWindowSummary::count(self : ProductionWindowSummary) -> Int {
  self.count
}

///|
pub fn ProductionWindowSummary::valid_count(
  self : ProductionWindowSummary,
) -> Int {
  self.valid_count
}

///|
pub fn ProductionWindowSummary::imputed_count(
  self : ProductionWindowSummary,
) -> Int {
  self.imputed_count
}

///|
pub fn ProductionWindowSummary::late_count(
  self : ProductionWindowSummary,
) -> Int {
  self.late_count
}

///|
pub fn ProductionWindowSummary::sum(self : ProductionWindowSummary) -> Double {
  self.sum
}

///|
pub fn ProductionWindowSummary::mean(self : ProductionWindowSummary) -> Double {
  self.mean
}

///|
pub fn ProductionWindowSummary::variance(
  self : ProductionWindowSummary,
) -> Double {
  self.variance
}

///|
pub fn ProductionWindowSummary::minimum(
  self : ProductionWindowSummary,
) -> Double {
  self.minimum
}

///|
pub fn ProductionWindowSummary::maximum(
  self : ProductionWindowSummary,
) -> Double {
  self.maximum
}

///|
pub fn ProductionWindowSummary::median(
  self : ProductionWindowSummary,
) -> Double {
  self.median
}

///|
pub fn ProductionWindowSummary::first(self : ProductionWindowSummary) -> Double {
  self.first
}

///|
pub fn ProductionWindowSummary::last(self : ProductionWindowSummary) -> Double {
  self.last
}

///|
pub fn ProductionWindowSummary::range(self : ProductionWindowSummary) -> Double {
  self.maximum - self.minimum
}

///|
pub fn ProductionWindowSummary::has_imputation(
  self : ProductionWindowSummary,
) -> Bool {
  self.imputed_count > 0
}

///|
pub fn ProductionWindowSummary::quality_ratio(
  self : ProductionWindowSummary,
) -> Double {
  if self.count == 0 {
    1.0
  } else {
    self.valid_count.to_double() / self.count.to_double()
  }
}

///|
pub fn ProductionWindowSummary::slope(self : ProductionWindowSummary) -> Double {
  if self.end_timestamp <= self.start_timestamp {
    0.0
  } else {
    (self.last - self.first) /
    (self.end_timestamp - self.start_timestamp).to_double()
  }
}

///|
/// A bounded time-ordered window with explicit retention accounting.
pub struct ProductionTimeWindow {
  capacity : Int
  values : Array[ProductionSample]
  mut start_index : Int
  mut length : Int
  mut dropped : Int
}

///|
pub fn ProductionTimeWindow::new(capacity? : Int = 256) -> ProductionTimeWindow {
  let safe_capacity = if capacity < 1 { 1 } else { capacity }
  {
    capacity: safe_capacity,
    values: Array::make(safe_capacity, ProductionSample::new(0L, 0.0)),
    start_index: 0,
    length: 0,
    dropped: 0,
  }
}

///|
pub fn ProductionTimeWindow::capacity(self : ProductionTimeWindow) -> Int {
  self.capacity
}

///|
pub fn ProductionTimeWindow::length(self : ProductionTimeWindow) -> Int {
  self.length
}

///|
pub fn ProductionTimeWindow::dropped(self : ProductionTimeWindow) -> Int {
  self.dropped
}

///|
pub fn ProductionTimeWindow::is_full(self : ProductionTimeWindow) -> Bool {
  self.length == self.capacity
}

///|
pub fn ProductionTimeWindow::is_empty(self : ProductionTimeWindow) -> Bool {
  self.length == 0
}

///|
fn ProductionTimeWindow::physical_index(
  self : ProductionTimeWindow,
  index : Int,
) -> Int {
  (self.start_index + index) % self.capacity
}

///|
pub fn ProductionTimeWindow::get(
  self : ProductionTimeWindow,
  index : Int,
) -> ProductionSample? {
  if index < 0 || index >= self.length {
    None
  } else {
    Some(self.values[self.physical_index(index)])
  }
}

///|
pub fn ProductionTimeWindow::first(
  self : ProductionTimeWindow,
) -> ProductionSample? {
  self.get(0)
}

///|
pub fn ProductionTimeWindow::last(
  self : ProductionTimeWindow,
) -> ProductionSample? {
  self.get(self.length - 1)
}

///|
pub fn ProductionTimeWindow::push(
  self : ProductionTimeWindow,
  sample : ProductionSample,
) -> ProductionSample? {
  if self.length < self.capacity {
    let position = self.physical_index(self.length)
    self.values[position] = sample
    self.length += 1
    None
  } else {
    let evicted = self.values[self.start_index]
    self.values[self.start_index] = sample
    self.start_index = (self.start_index + 1) % self.capacity
    self.dropped += 1
    Some(evicted)
  }
}

///|
pub fn ProductionTimeWindow::clear(self : ProductionTimeWindow) -> Unit {
  self.start_index = 0
  self.length = 0
}

///|
pub fn ProductionTimeWindow::to_array(
  self : ProductionTimeWindow,
) -> Array[ProductionSample] {
  let result : Array[ProductionSample] = []
  for i in 0..<self.length {
    result.push(self.values[self.physical_index(i)])
  }
  result
}

///|
pub fn ProductionTimeWindow::values(
  self : ProductionTimeWindow,
) -> Array[Double] {
  let result : Array[Double] = []
  for sample in self.to_array() {
    if is_finite(sample.value) {
      result.push(sample.value)
    }
  }
  result
}

///|
pub fn ProductionTimeWindow::timestamps(
  self : ProductionTimeWindow,
) -> Array[Int64] {
  let result : Array[Int64] = []
  for sample in self.to_array() {
    result.push(sample.timestamp)
  }
  result
}

///|
pub fn ProductionTimeWindow::summary(
  self : ProductionTimeWindow,
) -> ProductionWindowSummary {
  let samples = self.to_array()
  if samples.length() == 0 {
    return ProductionWindowSummary::empty()
  }
  let values : Array[Double] = []
  let mut valid_count = 0
  let mut imputed_count = 0
  let mut late_count = 0
  for sample in samples {
    if is_finite(sample.value) {
      values.push(sample.value)
      valid_count += 1
    }
    if sample.imputed {
      imputed_count += 1
    }
    if sample.late {
      late_count += 1
    }
  }
  let first = samples[0]
  let last = samples[samples.length() - 1]
  if values.length() == 0 {
    return {
      start_timestamp: first.timestamp,
      end_timestamp: last.timestamp,
      count: samples.length(),
      valid_count,
      imputed_count,
      late_count,
      sum: 0.0,
      mean: 0.0,
      variance: 0.0,
      minimum: 0.0,
      maximum: 0.0,
      median: 0.0,
      first: first.value,
      last: last.value,
    }
  }
  {
    start_timestamp: first.timestamp,
    end_timestamp: last.timestamp,
    count: samples.length(),
    valid_count,
    imputed_count,
    late_count,
    sum: sum(values),
    mean: mean(values),
    variance: variance(values),
    minimum: array_minimum(values),
    maximum: array_maximum(values),
    median: median(values),
    first: first.value,
    last: last.value,
  }
}

///|
pub fn ProductionTimeWindow::rolling_change(
  self : ProductionTimeWindow,
  split : Int,
) -> Double {
  let values = self.values()
  if split < 1 || split >= values.length() {
    return 0.0
  }
  let left : Array[Double] = []
  let right : Array[Double] = []
  for i in 0..<split {
    left.push(values[i])
  }
  for i in split..<values.length() {
    right.push(values[i])
  }
  absolute(mean(right) - mean(left))
}

///|
pub fn ProductionTimeWindow::outlier_count(
  self : ProductionTimeWindow,
  z_limit? : Double = 3.0,
) -> Int {
  let values = self.values()
  if values.length() < 2 {
    return 0
  }
  let center = median(values)
  let scale = median_absolute_deviation(values)
  let safe_scale = if scale < 1.0e-12 {
    standard_deviation(values)
  } else {
    scale
  }
  if safe_scale < 1.0e-12 {
    return 0
  }
  let limit = if z_limit < 0.0 { 0.0 } else { z_limit }
  let mut count = 0
  for value in values {
    if absolute(value - center) / safe_scale > limit {
      count += 1
    }
  }
  count
}

///|
/// Fixed-size aggregation by event-time interval.
pub struct ProductionBucket {
  start_timestamp : Int64
  end_timestamp : Int64
  samples : Array[ProductionSample]
}

///|
pub fn ProductionBucket::new(
  start_timestamp : Int64,
  size : Int64,
) -> ProductionBucket {
  { start_timestamp, end_timestamp: start_timestamp + size, samples: [] }
}

///|
pub fn ProductionBucket::start(self : ProductionBucket) -> Int64 {
  self.start_timestamp
}

///|
pub fn ProductionBucket::end(self : ProductionBucket) -> Int64 {
  self.end_timestamp
}

///|
pub fn ProductionBucket::count(self : ProductionBucket) -> Int {
  self.samples.length()
}

///|
pub fn ProductionBucket::push(
  self : ProductionBucket,
  sample : ProductionSample,
) -> Bool {
  if sample.timestamp < self.start_timestamp ||
    sample.timestamp >= self.end_timestamp {
    false
  } else {
    self.samples.push(sample)
    true
  }
}

///|
pub fn ProductionBucket::summary(
  self : ProductionBucket,
) -> ProductionWindowSummary {
  let window = ProductionTimeWindow::new(capacity=self.samples.length() + 1)
  for sample in self.samples {
    ignore(window.push(sample))
  }
  window.summary()
}

///|
pub fn ProductionBucket::mean(self : ProductionBucket) -> Double {
  self.summary().mean()
}

///|
pub fn ProductionBucket::sum(self : ProductionBucket) -> Double {
  self.summary().sum()
}

///|
pub fn ProductionBucket::to_points(
  self : ProductionBucket,
) -> Array[SignalPoint] {
  let result : Array[SignalPoint] = []
  for sample in self.samples {
    result.push(
      SignalPoint::new(sample.timestamp, sample.value, sequence=sample.sequence),
    )
  }
  result
}

///|
/// Event-time bucketizer that flushes complete intervals in order.
pub struct ProductionBucketizer {
  interval : Int64
  origin : Int64
  mut current : ProductionBucket?
  mut flushed : Int
  mut dropped : Int
}

///|
pub fn ProductionBucketizer::new(
  interval? : Int64 = 60L,
  origin? : Int64 = 0L,
) -> ProductionBucketizer {
  {
    interval: if interval < 1L {
      1L
    } else {
      interval
    },
    origin,
    current: None,
    flushed: 0,
    dropped: 0,
  }
}

///|
pub fn ProductionBucketizer::interval(self : ProductionBucketizer) -> Int64 {
  self.interval
}

///|
pub fn ProductionBucketizer::flushed(self : ProductionBucketizer) -> Int {
  self.flushed
}

///|
pub fn ProductionBucketizer::dropped(self : ProductionBucketizer) -> Int {
  self.dropped
}

///|
fn ProductionBucketizer::bucket_start(
  self : ProductionBucketizer,
  timestamp : Int64,
) -> Int64 {
  let delta = timestamp - self.origin
  let quotient = delta / self.interval
  self.origin + quotient * self.interval
}

///|
pub fn ProductionBucketizer::push(
  self : ProductionBucketizer,
  sample : ProductionSample,
) -> Array[ProductionBucket] {
  let output : Array[ProductionBucket] = []
  let start = self.bucket_start(sample.timestamp)
  match self.current {
    None => {
      let bucket = ProductionBucket::new(start, self.interval)
      ignore(bucket.push(sample))
      self.current = Some(bucket)
    }
    Some(bucket) =>
      if start < bucket.start() {
        self.dropped += 1
      } else if start == bucket.start() {
        ignore(bucket.push(sample))
      } else {
        output.push(bucket)
        self.flushed += 1
        let next = ProductionBucket::new(start, self.interval)
        ignore(next.push(sample))
        self.current = Some(next)
      }
  }
  output
}

///|
pub fn ProductionBucketizer::flush(
  self : ProductionBucketizer,
) -> Array[ProductionBucket] {
  match self.current {
    None => []
    Some(bucket) => {
      self.current = None
      self.flushed += 1
      [bucket]
    }
  }
}

///|
/// Policy for values in empty resampling buckets.
pub(all) enum ProductionFillPolicy {
  ForwardFill
  ZeroFill
  LinearInterpolate
  SkipEmpty
}

///|
/// Converts irregular event-time samples into a regular grid.
pub struct ProductionResampler {
  step : Int64
  policy : ProductionFillPolicy
  mut origin : Int64?
  mut last : ProductionSample?
  mut pending_empty : Int
  mut produced : Int
}

///|
pub fn ProductionResampler::new(
  step? : Int64 = 60L,
  policy? : ProductionFillPolicy = ForwardFill,
) -> ProductionResampler {
  {
    step: if step < 1L {
      1L
    } else {
      step
    },
    policy,
    origin: None,
    last: None,
    pending_empty: 0,
    produced: 0,
  }
}

///|
pub fn ProductionResampler::step(self : ProductionResampler) -> Int64 {
  self.step
}

///|
pub fn ProductionResampler::produced(self : ProductionResampler) -> Int {
  self.produced
}

///|
pub fn ProductionResampler::pending_empty(self : ProductionResampler) -> Int {
  self.pending_empty
}

///|
fn ProductionResampler::grid_timestamp(
  self : ProductionResampler,
  timestamp : Int64,
) -> Int64 {
  match self.origin {
    None => timestamp
    Some(origin) => {
      let delta = timestamp - origin
      origin + delta / self.step * self.step
    }
  }
}

///|
fn ProductionResampler::fill_between(
  self : ProductionResampler,
  previous : ProductionSample,
  target : Int64,
  next_value : Double,
) -> Array[ProductionSample] {
  let result : Array[ProductionSample] = []
  let distance = target - previous.timestamp
  if distance <= self.step {
    return result
  }
  let steps = distance / self.step - 1L
  for i in 1L..<=steps {
    let timestamp = previous.timestamp + i * self.step
    let value = match self.policy {
      ForwardFill => previous.value
      ZeroFill => 0.0
      LinearInterpolate => {
        let ratio = i.to_double() / (steps + 1L).to_double()
        previous.value + (next_value - previous.value) * ratio
      }
      SkipEmpty => continue
    }
    result.push(ProductionSample::new(timestamp, value, imputed=true))
  }
  result
}

///|
pub fn ProductionResampler::push(
  self : ProductionResampler,
  sample : ProductionSample,
) -> Array[ProductionSample] {
  let output : Array[ProductionSample] = []
  if !is_finite(sample.value) {
    return output
  }
  if self.origin is None {
    self.origin = Some(sample.timestamp)
  }
  let aligned = self.grid_timestamp(sample.timestamp)
  match self.last {
    None => {
      let first = ProductionSample::new(
        aligned,
        sample.value,
        sequence=sample.sequence,
        imputed=sample.imputed,
        late=sample.late,
      )
      output.push(first)
      self.produced += 1
      self.last = Some(first)
    }
    Some(previous) =>
      if aligned <= previous.timestamp {
        if aligned == previous.timestamp {
          self.last = Some(
            ProductionSample::new(
              aligned,
              sample.value,
              sequence=sample.sequence,
              imputed=sample.imputed,
              late=sample.late,
            ),
          )
        }
      } else {
        let filled = self.fill_between(previous, aligned, sample.value)
        for value in filled {
          output.push(value)
          self.produced += 1
        }
        let current = ProductionSample::new(
          aligned,
          sample.value,
          sequence=sample.sequence,
          imputed=sample.imputed,
          late=sample.late,
        )
        output.push(current)
        self.produced += 1
        self.pending_empty = 0
        self.last = Some(current)
      }
  }
  output
}

///|
pub fn ProductionResampler::flush(
  self : ProductionResampler,
) -> Array[ProductionSample] {
  match self.last {
    None => []
    Some(sample) => {
      self.last = None
      self.origin = None
      self.pending_empty = 0
      [sample]
    }
  }
}

///|
/// Tracks rates and counter resets for monotonic telemetry.
pub struct ProductionRateTracker {
  mut previous_timestamp : Int64?
  mut previous_value : Double?
  mut resets : Int
  mut invalid : Int
}

///|
pub fn ProductionRateTracker::new() -> ProductionRateTracker {
  { previous_timestamp: None, previous_value: None, resets: 0, invalid: 0 }
}

///|
pub fn ProductionRateTracker::resets(self : ProductionRateTracker) -> Int {
  self.resets
}

///|
pub fn ProductionRateTracker::invalid(self : ProductionRateTracker) -> Int {
  self.invalid
}

///|
pub fn ProductionRateTracker::push(
  self : ProductionRateTracker,
  timestamp : Int64,
  value : Double,
) -> Double? {
  if !is_finite(value) {
    self.invalid += 1
    return None
  }
  let result = match (self.previous_timestamp, self.previous_value) {
    (Some(previous_timestamp), Some(previous_value)) => {
      let elapsed = timestamp - previous_timestamp
      if elapsed <= 0L {
        self.invalid += 1
        None
      } else if value < previous_value {
        self.resets += 1
        None
      } else {
        Some((value - previous_value) / elapsed.to_double())
      }
    }
    _ => None
  }
  self.previous_timestamp = Some(timestamp)
  self.previous_value = Some(value)
  result
}

///|
/// A rolling rate and change summary used for counter-based metrics.
pub struct ProductionRateSummary {
  samples : Int
  resets : Int
  invalid : Int
  mean_rate : Double
  maximum_rate : Double
  latest_rate : Double
}

///|
pub fn ProductionRateSummary::from_points(
  points : Array[SignalPoint],
) -> ProductionRateSummary {
  let tracker = ProductionRateTracker::new()
  let rates : Array[Double] = []
  for point in points {
    match tracker.push(point.timestamp, point.value) {
      None => ()
      Some(rate) => rates.push(rate)
    }
  }
  {
    samples: rates.length(),
    resets: tracker.resets(),
    invalid: tracker.invalid(),
    mean_rate: mean(rates),
    maximum_rate: array_maximum(rates),
    latest_rate: if rates.length() == 0 {
      0.0
    } else {
      rates[rates.length() - 1]
    },
  }
}

///|
pub fn ProductionRateSummary::samples(self : ProductionRateSummary) -> Int {
  self.samples
}

///|
pub fn ProductionRateSummary::resets(self : ProductionRateSummary) -> Int {
  self.resets
}

///|
pub fn ProductionRateSummary::invalid(self : ProductionRateSummary) -> Int {
  self.invalid
}

///|
pub fn ProductionRateSummary::mean_rate(self : ProductionRateSummary) -> Double {
  self.mean_rate
}

///|
pub fn ProductionRateSummary::maximum_rate(
  self : ProductionRateSummary,
) -> Double {
  self.maximum_rate
}

///|
pub fn ProductionRateSummary::latest_rate(
  self : ProductionRateSummary,
) -> Double {
  self.latest_rate
}

///|
/// Computes a bounded rolling percentage change series.
pub fn production_percent_changes(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  if values.length() < 2 {
    return result
  }
  for i in 1..<values.length() {
    let previous = values[i - 1]
    if absolute(previous) < 1.0e-12 {
      result.push(0.0)
    } else {
      result.push((values[i] - previous) / absolute(previous))
    }
  }
  result
}

///|
/// Calculates a rolling range without exposing mutable window state.
pub fn production_rolling_ranges(
  values : Array[Double],
  width? : Int = 8,
) -> Array[Double] {
  let safe_width = if width < 1 { 1 } else { width }
  let result : Array[Double] = []
  for i in 0..<values.length() {
    let start = if i + 1 < safe_width { 0 } else { i + 1 - safe_width }
    let sample : Array[Double] = []
    for j in start..<=i {
      sample.push(values[j])
    }
    result.push(array_maximum(sample) - array_minimum(sample))
  }
  result
}

///|
/// Computes rolling volatility using a population standard deviation.
pub fn production_rolling_volatility(
  values : Array[Double],
  width? : Int = 8,
) -> Array[Double] {
  let safe_width = if width < 1 { 1 } else { width }
  let result : Array[Double] = []
  for i in 0..<values.length() {
    let start = if i + 1 < safe_width { 0 } else { i + 1 - safe_width }
    let sample : Array[Double] = []
    for j in start..<=i {
      sample.push(values[j])
    }
    result.push(standard_deviation(sample))
  }
  result
}

///|
/// Returns a copy with invalid values replaced according to a production policy.
pub fn production_impute_values(
  values : Array[Double],
  strategy : MissingValueStrategy,
) -> Array[Double] {
  let result : Array[Double] = []
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
      result.push(value)
      last = value
    } else {
      match strategy {
        DropValue => ()
        MarkUnknown => result.push(value)
        ImputeLast => result.push(last)
        ImputeMean => result.push(fallback)
        ImputeZero => result.push(0.0)
      }
    }
  }
  result
}

///|
/// Counts samples by late-data and imputation flags for quality dashboards.
pub fn production_sample_quality(
  samples : Array[ProductionSample],
) -> (Int, Int, Int) {
  let mut imputed = 0
  let mut late = 0
  let mut invalid = 0
  for sample in samples {
    if sample.imputed {
      imputed += 1
    }
    if sample.late {
      late += 1
    }
    if !is_finite(sample.value) {
      invalid += 1
    }
  }
  (imputed, late, invalid)
}
