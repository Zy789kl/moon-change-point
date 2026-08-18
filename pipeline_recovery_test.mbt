///|
test "metric pipeline emits an event only after policy acceptance" {
  let pipeline = MetricPipeline::new(
    "latency",
    LegacyDetector(
      Detector::new(CusumDetector(Cusum::new(control_limit=1.0, drift=0.0))),
    ),
    policy=AlertPolicy::new(minimum_score=0.0),
  )
  let mut emitted = 0
  for i in 0..<20 {
    match pipeline.process(i.to_int64(), if i < 5 { 0.0 } else { 4.0 }) {
      None => ()
      Some(_) => emitted += 1
    }
  }
  assert_true(emitted >= 1)
  assert_eq(pipeline.index(), 20)
}

///|
test "multi metric monitor counts processed points" {
  let first = MetricPipeline::new(
    "a",
    LegacyDetector(Detector::new(CusumDetector(Cusum::new(control_limit=2.0)))),
  )
  let second = MetricPipeline::new(
    "b",
    RobustZ(RobustZDetector::new(window_size=3)),
  )
  let monitor = MultiMetricMonitor::new([first, second])
  assert_eq(monitor.metric_count(), 2)
  ignore(monitor.process(0, 1L, 1.0))
  ignore(monitor.process(1, 1L, 1.0))
  assert_eq(monitor.processed_count(), 2)
}

///|
test "stream engine flushes a partial aggregate" {
  let engine = StreamEngine::new(
    "cpu",
    LegacyDetector(Detector::new(CusumDetector(Cusum::new(control_limit=2.0)))),
    window_size=3,
    lateness=1,
  )
  for i in 0..<5 {
    ignore(engine.process_point(SignalPoint::new(i.to_int64(), i.to_double())))
  }
  ignore(engine.flush())
  assert_eq(engine.processed(), 5)
  assert_true(engine.aggregate_count() >= 1)
}

///|
test "watermark tracker rejects points outside lateness" {
  let tracker = WatermarkTracker::new(allowed_lateness=2L)
  assert_true(tracker.observe(10L))
  assert_true(tracker.observe(8L))
  assert_true(!tracker.observe(1L))
  assert_eq(tracker.accepted(), 2)
  assert_eq(tracker.dropped(), 1)
}

///|
test "aggregator closes exact and partial windows" {
  let aggregator = WindowAggregator::new(2, kind=SumAggregate)
  match aggregator.push(SignalPoint::new(0L, 1.0)) {
    None => ()
    Some(_) => fail("window closed too early")
  }
  match aggregator.push(SignalPoint::new(1L, 2.0)) {
    None => fail("window did not close")
    Some(window) => assert_eq(window.value, 3.0)
  }
  match aggregator.flush() {
    None => ()
    Some(_) => fail("empty window flushed")
  }
}

///|
test "late data policy produces deterministic reorder output" {
  let buffer = ReorderBuffer::new(capacity=3, policy=KeepForCorrection)
  let first = buffer.push(SignalPoint::new(10L, 10.0))
  let second = buffer.push(SignalPoint::new(8L, 8.0))
  assert_true(first.length() + second.length() <= 2)
  let flushed = buffer.flush()
  assert_true(flushed.length() >= 1)
  assert_true(
    flushed[0].point.timestamp <= flushed[flushed.length() - 1].point.timestamp,
  )
}

///|
test "event history obeys capacity and deduplication" {
  let history = EventHistory::new(capacity=2)
  let point = ChangePoint::from_result(
    SignalPoint::new(1L, 2.0),
    DetectionResult::new(true, 0.8, 0.8, Increase, 1),
    "test",
    1.0,
  )
  history.push(AlertEvent::new("metric", point, ordinal=1))
  history.push(AlertEvent::new("metric", point, ordinal=2))
  history.push(AlertEvent::new("metric", point, ordinal=3))
  assert_eq(history.length(), 2)
  assert_eq(history.total(), 3)
}

///|
test "consecutive and vote rules debounce noise" {
  let consecutive = ConsecutiveRule::new(required=2)
  assert_true(!consecutive.push(true))
  assert_true(consecutive.push(true))
  let vote = VoteRule::new(size=3, required=2)
  assert_true(!vote.push(true))
  assert_true(!vote.push(false))
  assert_true(vote.push(true))
  assert_eq(vote.votes(), 2)
}

///|
test "hysteresis rule prevents threshold flapping" {
  let rule = HysteresisRule::new(enter_threshold=0.8, exit_threshold=0.4)
  assert_true(!rule.push(0.7))
  assert_true(rule.push(0.9))
  assert_true(rule.push(0.5))
  assert_true(!rule.push(0.3))
}

///|
test "alert budget suppresses after capacity is spent" {
  let budget = AlertBudget::new(capacity=2, refill=0.0)
  assert_true(budget.allow())
  assert_true(budget.allow())
  assert_true(!budget.allow())
  assert_eq(budget.suppressed(), 1)
}

///|
test "event rates handle zero duration" {
  assert_eq(event_rate([], 1L, 1L), 0.0)
  assert_eq(event_rate([], 2L, 1L), 0.0)
}
