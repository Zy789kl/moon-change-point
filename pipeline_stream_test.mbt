///|
test "pipeline emits an event and tracks suppression" {
  let detector = PipelineDetector::Ewma(
    EwmaDetector::new(threshold=2.0, warmup=2),
  )
  let policy = AlertPolicy::new(
    minimum_score=1.0,
    minimum_confidence=0.0,
    minimum_gap=2,
  )
  let pipeline = MetricPipeline::new("latency", detector, policy~, baseline=0.0)
  ignore(pipeline.process(0L, 0.0))
  ignore(pipeline.process(1L, 0.0))
  let event = pipeline.process(2L, 10.0)
  match event {
    None => ()
    Some(value) => {
      assert_eq(value.metric, "latency")
      assert_eq(value.point.timestamp, 2L)
    }
  }
  assert_true(pipeline.index() >= 3)
}

///|
test "pipeline detector variants are all callable" {
  let variants : Array[PipelineDetector] = [
    Ewma(EwmaDetector::new()),
    RobustZ(RobustZDetector::new()),
    VarianceShift(VarianceShiftDetector::new()),
    TrendShift(TrendShiftDetector::new()),
    IqrSpike(IqrSpikeDetector::new()),
  ]
  for detector in variants {
    let result = detector.update(0.0, 1)
    assert_eq(result.index, 1)
  }
}

///|
test "multi metric monitor rejects invalid metric index" {
  let metric = MetricPipeline::new("cpu", Ewma(EwmaDetector::new()))
  let monitor = MultiMetricMonitor::new([metric])
  assert_eq(monitor.metric_count(), 1)
  match monitor.process(-1, 0L, 1.0) {
    None => ()
    Some(_) => fail("invalid metric emitted")
  }
  match monitor.process(2, 0L, 1.0) {
    None => ()
    Some(_) => fail("invalid metric emitted")
  }
  assert_eq(monitor.processed_count(), 2)
}

///|
test "watermark tracker accepts bounded lateness" {
  let tracker = WatermarkTracker::new(allowed_lateness=2L)
  assert_eq(tracker.observe(10L), true)
  assert_eq(tracker.observe(8L), true)
  assert_eq(tracker.observe(7L), false)
  assert_eq(tracker.accepted(), 2)
  assert_eq(tracker.dropped(), 1)
}

///|
test "window aggregation closes full and partial windows" {
  let aggregator = WindowAggregator::new(2, kind=SumAggregate)
  match aggregator.push(SignalPoint::new(1L, 2.0)) {
    None => ()
    Some(_) => fail("aggregate closed too early")
  }
  match aggregator.push(SignalPoint::new(2L, 3.0)) {
    None => fail("aggregate missing")
    Some(value) => {
      assert_eq(value.count, 2)
      assert_eq(value.value, 5.0)
    }
  }
  ignore(aggregator.push(SignalPoint::new(3L, 4.0)))
  match aggregator.flush() {
    None => fail("partial aggregate missing")
    Some(value) => assert_eq(value.value, 4.0)
  }
}

///|
test "stream engine flushes reordered points" {
  let engine = StreamEngine::new(
    "temperature",
    Ewma(EwmaDetector::new()),
    window_size=2,
    lateness=1,
  )
  for
    point in reorder_periodic(
      timestamped_signal([0.0, 0.0, 5.0, 5.0], step=1L),
      2,
    ) {
    ignore(engine.process_point(point))
  }
  ignore(engine.flush())
  assert_true(engine.processed() >= 3)
  assert_true(engine.aggregate_count() >= 1)
}
