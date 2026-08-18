///|
/// Aggregation choices for a fixed streaming window.
pub(all) enum AggregationKind {
  MeanAggregate
  SumAggregate
  MinimumAggregate
  MaximumAggregate
  StandardDeviationAggregate
}

///|
pub struct WindowAggregate {
  start_timestamp : Int64
  end_timestamp : Int64
  count : Int
  value : Double
  summary : StatsSummary
}

///|
pub struct WindowAggregator {
  size : Int
  kind : AggregationKind
  window : DoubleWindow
  mut start_timestamp : Int64
  mut end_timestamp : Int64
  mut count : Int
}

///|
pub fn WindowAggregator::new(
  size : Int,
  kind? : AggregationKind = MeanAggregate,
) -> WindowAggregator {
  {
    size: if size < 1 {
      1
    } else {
      size
    },
    kind,
    window: DoubleWindow::new(if size < 1 { 1 } else { size }),
    start_timestamp: 0L,
    end_timestamp: 0L,
    count: 0,
  }
}

///|
fn WindowAggregator::value(self : WindowAggregator) -> Double {
  match self.kind {
    MeanAggregate => self.window.mean()
    SumAggregate => self.window.sum()
    MinimumAggregate => array_minimum(self.window.to_array())
    MaximumAggregate => array_maximum(self.window.to_array())
    StandardDeviationAggregate => self.window.standard_deviation()
  }
}

///|
fn WindowAggregator::close(self : WindowAggregator) -> WindowAggregate {
  {
    start_timestamp: self.start_timestamp,
    end_timestamp: self.end_timestamp,
    count: self.count,
    value: self.value(),
    summary: self.window.snapshot(),
  }
}

///|
pub fn WindowAggregator::push(
  self : WindowAggregator,
  point : SignalPoint,
) -> WindowAggregate? {
  if self.count == 0 {
    self.start_timestamp = point.timestamp
  }
  self.end_timestamp = point.timestamp
  self.count += 1
  ignore(self.window.push(point.value))
  if self.count >= self.size {
    let result = self.close()
    self.window.clear()
    self.count = 0
    Some(result)
  } else {
    None
  }
}

///|
pub fn WindowAggregator::flush(self : WindowAggregator) -> WindowAggregate? {
  if self.count == 0 {
    None
  } else {
    let result = self.close()
    self.window.clear()
    self.count = 0
    Some(result)
  }
}

///|
pub struct WatermarkTracker {
  allowed_lateness : Int64
  mut maximum_seen : Int64
  mut accepted : Int
  mut dropped : Int
}

///|
pub fn WatermarkTracker::new(
  allowed_lateness? : Int64 = 5L,
) -> WatermarkTracker {
  {
    allowed_lateness: if allowed_lateness < 0L {
      0L
    } else {
      allowed_lateness
    },
    maximum_seen: -9223372036854775807L,
    accepted: 0,
    dropped: 0,
  }
}

///|
pub fn WatermarkTracker::watermark(self : WatermarkTracker) -> Int64 {
  self.maximum_seen - self.allowed_lateness
}

///|
pub fn WatermarkTracker::observe(
  self : WatermarkTracker,
  timestamp : Int64,
) -> Bool {
  let accepted = self.maximum_seen == -9223372036854775807L ||
    timestamp >= self.watermark()
  if timestamp > self.maximum_seen {
    self.maximum_seen = timestamp
  }
  if accepted {
    self.accepted += 1
  } else {
    self.dropped += 1
  }
  accepted
}

///|
pub fn WatermarkTracker::accepted(self : WatermarkTracker) -> Int {
  self.accepted
}

///|
pub fn WatermarkTracker::dropped(self : WatermarkTracker) -> Int {
  self.dropped
}

///|
/// End-to-end stream state: reorder, aggregate, and detect.
pub struct StreamEngine {
  reorder : ReorderBuffer
  tracker : WatermarkTracker
  aggregator : WindowAggregator
  pipeline : MetricPipeline
  mut processed : Int
  mut aggregates : Int
  mut alerts : Int
}

///|
pub fn StreamEngine::new(
  metric : String,
  detector : PipelineDetector,
  window_size? : Int = 16,
  lateness? : Int = 4,
) -> StreamEngine {
  {
    reorder: ReorderBuffer::new(capacity=lateness + 1, policy=KeepForCorrection),
    tracker: WatermarkTracker::new(allowed_lateness=lateness.to_int64()),
    aggregator: WindowAggregator::new(window_size),
    pipeline: MetricPipeline::new(metric, detector),
    processed: 0,
    aggregates: 0,
    alerts: 0,
  }
}

///|
pub fn StreamEngine::process_point(
  self : StreamEngine,
  point : SignalPoint,
) -> Array[AlertEvent] {
  let result : Array[AlertEvent] = []
  let ready = self.reorder.push(point)
  for ordered in ready {
    if !self.tracker.observe(ordered.point.timestamp) {
      continue
    }
    self.processed += 1
    match self.aggregator.push(ordered.point) {
      None => ()
      Some(aggregate) => {
        self.aggregates += 1
        match self.pipeline.process(aggregate.end_timestamp, aggregate.value) {
          None => ()
          Some(alert) => {
            self.alerts += 1
            result.push(alert)
          }
        }
      }
    }
  }
  result
}

///|
pub fn StreamEngine::flush(self : StreamEngine) -> Array[AlertEvent] {
  let result : Array[AlertEvent] = []
  let pending = self.reorder.flush()
  for ordered in pending {
    if !self.tracker.observe(ordered.point.timestamp) {
      continue
    }
    self.processed += 1
    match self.aggregator.push(ordered.point) {
      None => ()
      Some(aggregate) => {
        self.aggregates += 1
        match self.pipeline.process(aggregate.end_timestamp, aggregate.value) {
          None => ()
          Some(alert) => {
            self.alerts += 1
            result.push(alert)
          }
        }
      }
    }
  }
  match self.aggregator.flush() {
    None => ()
    Some(aggregate) =>
      match self.pipeline.process(aggregate.end_timestamp, aggregate.value) {
        None => ()
        Some(alert) => result.push(alert)
      }
  }
  result
}

///|
pub fn StreamEngine::processed(self : StreamEngine) -> Int {
  self.processed
}

///|
pub fn StreamEngine::aggregate_count(self : StreamEngine) -> Int {
  self.aggregates
}

///|
pub fn StreamEngine::alert_count(self : StreamEngine) -> Int {
  self.alerts
}
