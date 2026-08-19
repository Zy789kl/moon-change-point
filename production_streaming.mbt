///|
/// Policy used when an in-memory stream queue reaches capacity.
pub(all) enum ProductionBackpressurePolicy {
  DropNewestSample
  DropOldestSample
  RejectProducer
}

///|
pub fn production_backpressure_policy_name(
  policy : ProductionBackpressurePolicy,
) -> String {
  match policy {
    DropNewestSample => "drop-newest"
    DropOldestSample => "drop-oldest"
    RejectProducer => "reject"
  }
}

///|
/// Bounded queue with explicit loss accounting.
pub struct ProductionSampleQueue {
  capacity : Int
  policy : ProductionBackpressurePolicy
  samples : Array[ProductionSample]
  mut accepted : Int
  mut dropped : Int
  mut rejected : Int
}

///|
pub fn ProductionSampleQueue::new(
  capacity? : Int = 1024,
  policy? : ProductionBackpressurePolicy = DropOldestSample,
) -> ProductionSampleQueue {
  {
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    policy,
    samples: [],
    accepted: 0,
    dropped: 0,
    rejected: 0,
  }
}

///|
pub fn ProductionSampleQueue::capacity(self : ProductionSampleQueue) -> Int {
  self.capacity
}

///|
pub fn ProductionSampleQueue::length(self : ProductionSampleQueue) -> Int {
  self.samples.length()
}

///|
pub fn ProductionSampleQueue::accepted(self : ProductionSampleQueue) -> Int {
  self.accepted
}

///|
pub fn ProductionSampleQueue::dropped(self : ProductionSampleQueue) -> Int {
  self.dropped
}

///|
pub fn ProductionSampleQueue::rejected(self : ProductionSampleQueue) -> Int {
  self.rejected
}

///|
pub fn ProductionSampleQueue::policy(
  self : ProductionSampleQueue,
) -> ProductionBackpressurePolicy {
  self.policy
}

///|
pub fn ProductionSampleQueue::push(
  self : ProductionSampleQueue,
  sample : ProductionSample,
) -> Bool {
  if self.samples.length() < self.capacity {
    self.samples.push(sample)
    self.accepted += 1
    true
  } else {
    match self.policy {
      DropNewestSample => {
        self.dropped += 1
        false
      }
      DropOldestSample => {
        ignore(self.samples.remove(0))
        self.samples.push(sample)
        self.accepted += 1
        self.dropped += 1
        true
      }
      RejectProducer => {
        self.rejected += 1
        false
      }
    }
  }
}

///|
pub fn ProductionSampleQueue::pop(
  self : ProductionSampleQueue,
) -> ProductionSample? {
  if self.samples.length() == 0 {
    None
  } else {
    Some(self.samples.remove(0))
  }
}

///|
pub fn ProductionSampleQueue::drain(
  self : ProductionSampleQueue,
) -> Array[ProductionSample] {
  let result : Array[ProductionSample] = []
  while self.samples.length() > 0 {
    result.push(self.samples.remove(0))
  }
  result
}

///|
pub fn ProductionSampleQueue::peek(
  self : ProductionSampleQueue,
) -> ProductionSample? {
  if self.samples.length() == 0 {
    None
  } else {
    Some(self.samples[0])
  }
}

///|
pub fn ProductionSampleQueue::clear(self : ProductionSampleQueue) -> Unit {
  self.samples.clear()
}

///|
/// Runtime state of a stream processor.
pub(all) enum ProductionStreamStatus {
  StartingStream
  RunningStream
  PausedStream
  DrainingStream
  StoppedStream
}

///|
pub fn production_stream_status_name(status : ProductionStreamStatus) -> String {
  match status {
    StartingStream => "starting"
    RunningStream => "running"
    PausedStream => "paused"
    DrainingStream => "draining"
    StoppedStream => "stopped"
  }
}

///|
/// Counters emitted by an online stream processor.
pub struct ProductionStreamMetrics {
  mut enqueued : Int
  mut processed : Int
  mut emitted : Int
  mut rejected : Int
  mut aggregates : Int
  mut flushes : Int
  mut last_timestamp : Int64
}

///|
pub fn ProductionStreamMetrics::new() -> ProductionStreamMetrics {
  {
    enqueued: 0,
    processed: 0,
    emitted: 0,
    rejected: 0,
    aggregates: 0,
    flushes: 0,
    last_timestamp: 0L,
  }
}

///|
pub fn ProductionStreamMetrics::enqueued(self : ProductionStreamMetrics) -> Int {
  self.enqueued
}

///|
pub fn ProductionStreamMetrics::processed(
  self : ProductionStreamMetrics,
) -> Int {
  self.processed
}

///|
pub fn ProductionStreamMetrics::emitted(self : ProductionStreamMetrics) -> Int {
  self.emitted
}

///|
pub fn ProductionStreamMetrics::rejected(self : ProductionStreamMetrics) -> Int {
  self.rejected
}

///|
pub fn ProductionStreamMetrics::aggregates(
  self : ProductionStreamMetrics,
) -> Int {
  self.aggregates
}

///|
pub fn ProductionStreamMetrics::flushes(self : ProductionStreamMetrics) -> Int {
  self.flushes
}

///|
pub fn ProductionStreamMetrics::last_timestamp(
  self : ProductionStreamMetrics,
) -> Int64 {
  self.last_timestamp
}

///|
pub fn ProductionStreamMetrics::throughput(
  self : ProductionStreamMetrics,
  elapsed : Int64,
) -> Double {
  if elapsed <= 0L {
    0.0
  } else {
    self.processed.to_double() / elapsed.to_double()
  }
}

///|
pub fn ProductionStreamMetrics::summary(
  self : ProductionStreamMetrics,
) -> String {
  "enqueued=" +
  self.enqueued.to_string() +
  ",processed=" +
  self.processed.to_string() +
  ",emitted=" +
  self.emitted.to_string() +
  ",rejected=" +
  self.rejected.to_string() +
  ",aggregates=" +
  self.aggregates.to_string() +
  ",flushes=" +
  self.flushes.to_string() +
  ",last=" +
  self.last_timestamp.to_string()
}

///|
/// Backpressure-aware processor joining queue, event-time bucketization and monitor state.
pub struct ProductionStreamProcessor {
  queue : ProductionSampleQueue
  bucketizer : ProductionBucketizer
  monitor : ProductionMonitor
  mut status : ProductionStreamStatus
  metrics : ProductionStreamMetrics
  mut started_at : Int64?
}

///|
pub fn ProductionStreamProcessor::new(
  monitor : ProductionMonitor,
  queue_capacity? : Int = 1024,
  queue_policy? : ProductionBackpressurePolicy = DropOldestSample,
  bucket_interval? : Int64 = 1L,
) -> ProductionStreamProcessor {
  {
    queue: ProductionSampleQueue::new(
      capacity=queue_capacity,
      policy=queue_policy,
    ),
    bucketizer: ProductionBucketizer::new(interval=bucket_interval),
    monitor,
    status: StartingStream,
    metrics: ProductionStreamMetrics::new(),
    started_at: None,
  }
}

///|
pub fn ProductionStreamProcessor::status(
  self : ProductionStreamProcessor,
) -> ProductionStreamStatus {
  self.status
}

///|
pub fn ProductionStreamProcessor::queue_length(
  self : ProductionStreamProcessor,
) -> Int {
  self.queue.length()
}

///|
pub fn ProductionStreamProcessor::metrics(
  self : ProductionStreamProcessor,
) -> ProductionStreamMetrics {
  self.metrics
}

///|
pub fn ProductionStreamProcessor::monitor(
  self : ProductionStreamProcessor,
) -> ProductionMonitor {
  self.monitor
}

///|
pub fn ProductionStreamProcessor::start(
  self : ProductionStreamProcessor,
  timestamp : Int64,
) -> Unit {
  self.status = RunningStream
  self.started_at = Some(timestamp)
}

///|
pub fn ProductionStreamProcessor::pause(
  self : ProductionStreamProcessor,
) -> Unit {
  if self.status is RunningStream {
    self.status = PausedStream
  }
}

///|
pub fn ProductionStreamProcessor::continue_processing(
  self : ProductionStreamProcessor,
) -> Unit {
  if self.status is PausedStream {
    self.status = RunningStream
  }
}

///|
pub fn ProductionStreamProcessor::enqueue(
  self : ProductionStreamProcessor,
  sample : ProductionSample,
) -> Bool {
  if self.status is StartingStream {
    self.start(sample.timestamp())
  }
  if self.status is PausedStream || self.status is StoppedStream {
    return false
  }
  self.metrics.enqueued += 1
  let accepted = self.queue.push(sample)
  if !accepted {
    self.metrics.rejected += 1
  }
  accepted
}

///|
fn ProductionStreamProcessor::process_bucket(
  self : ProductionStreamProcessor,
  bucket : ProductionBucket,
) -> Array[ProductionMonitorEvent] {
  let result : Array[ProductionMonitorEvent] = []
  let summary = bucket.summary()
  self.metrics.aggregates += 1
  let sample = ProductionSample::new(
    bucket.end(),
    summary.mean(),
    imputed=summary.imputed_count() > 0,
  )
  match self.monitor.update(sample) {
    None => ()
    Some(event) => {
      self.metrics.processed += 1
      self.metrics.last_timestamp = bucket.end()
      if event.result().changed {
        self.metrics.emitted += 1
      }
      result.push(event)
    }
  }
  result
}

///|
pub fn ProductionStreamProcessor::drain(
  self : ProductionStreamProcessor,
) -> Array[ProductionMonitorEvent] {
  if self.status is PausedStream || self.status is StoppedStream {
    return []
  }
  let result : Array[ProductionMonitorEvent] = []
  for sample in self.queue.drain() {
    for bucket in self.bucketizer.push(sample) {
      for event in self.process_bucket(bucket) {
        result.push(event)
      }
    }
  }
  result
}

///|
pub fn ProductionStreamProcessor::flush(
  self : ProductionStreamProcessor,
) -> Array[ProductionMonitorEvent] {
  self.status = DrainingStream
  let result = self.drain()
  for bucket in self.bucketizer.flush() {
    for event in self.process_bucket(bucket) {
      result.push(event)
    }
  }
  self.metrics.flushes += 1
  self.status = StoppedStream
  result
}

///|
pub fn ProductionStreamProcessor::restart(
  self : ProductionStreamProcessor,
  timestamp : Int64,
) -> Unit {
  self.queue.clear()
  self.monitor.reset()
  self.status = StartingStream
  self.started_at = Some(timestamp)
}

///|
pub fn ProductionStreamProcessor::elapsed(
  self : ProductionStreamProcessor,
  now : Int64,
) -> Int64 {
  match self.started_at {
    None => 0L
    Some(start) => if now > start { now - start } else { 0L }
  }
}

///|
pub fn production_stream_process_points(
  processor : ProductionStreamProcessor,
  points : Array[SignalPoint],
) -> Array[ProductionMonitorEvent] {
  let result : Array[ProductionMonitorEvent] = []
  for point in points {
    if processor.enqueue(
        ProductionSample::new(
          point.timestamp,
          point.value,
          sequence=point.sequence,
        ),
      ) {
      for event in processor.drain() {
        result.push(event)
      }
    }
  }
  for event in processor.flush() {
    result.push(event)
  }
  result
}

///|
pub fn production_stream_metrics_markdown(
  metrics : ProductionStreamMetrics,
  elapsed : Int64,
) -> String {
  "| metric | value |\n|---|---:|\n" +
  "| enqueued | " +
  metrics.enqueued().to_string() +
  " |\n" +
  "| processed | " +
  metrics.processed().to_string() +
  " |\n" +
  "| emitted | " +
  metrics.emitted().to_string() +
  " |\n" +
  "| rejected | " +
  metrics.rejected().to_string() +
  " |\n" +
  "| aggregates | " +
  metrics.aggregates().to_string() +
  " |\n" +
  "| flushes | " +
  metrics.flushes().to_string() +
  " |\n" +
  "| throughput | " +
  metrics.throughput(elapsed).to_string() +
  " |\n"
}
