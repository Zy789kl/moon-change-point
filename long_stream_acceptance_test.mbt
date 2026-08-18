///|
test "long stationary stream remains numerically stable" {
  let detector = RobustZDetector::new(window_size=32, threshold=3.5)
  let mut checksum = 0.0
  for i in 0..<1000 {
    let result = detector.update(10.0 + (i % 5).to_double() * 0.01)
    checksum += result.score
    assert_true(is_finite(result.score))
  }
  assert_true(is_finite(checksum))
}

///|
test "long shift stream produces a reproducible checksum" {
  let scenario = SignalScenario::mean_shift(
    length=512,
    change_at=256,
    baseline=10.0,
    shift=2.0,
    noise=0.1,
    seed=88L,
  )
  let values = generate_signal(scenario)
  let first = benchmark_cusum(scenario, rounds=2)
  let second = benchmark_cusum(scenario, rounds=2)
  assert_eq(values.length(), 512)
  assert_eq(first.checksum, second.checksum)
  assert_eq(first.passes, 1024)
}

///|
test "stream engine accepts ordered high volume input" {
  let engine = StreamEngine::new(
    "requests",
    LegacyDetector(Detector::new(CusumDetector(Cusum::new(control_limit=4.0)))),
    window_size=8,
    lateness=2,
  )
  for i in 0..<128 {
    let value = if i < 64 { 1.0 } else { 3.0 }
    ignore(engine.process_point(SignalPoint::new(i.to_int64(), value)))
  }
  ignore(engine.flush())
  assert_eq(engine.processed(), 128)
  assert_true(engine.aggregate_count() >= 16)
}

///|
test "multivariate stream accepts repeated fixed dimensions" {
  let detector = MahalanobisDetector::new(3, warmup=4)
  let mut last = DetectionResult::quiet()
  for i in 0..<40 {
    let value = if i < 20 { 1.0 } else { 5.0 }
    last = detector.update([value, value + 0.1, value - 0.1])
    assert_true(is_finite(last.score))
  }
  assert_eq(detector.count(), 40)
}

///|
test "offline analysis scales to a moderate sample" {
  let values : Array[Double] = []
  for i in 0..<300 {
    values.push(if i < 100 { 0.0 } else if i < 200 { 3.0 } else { -1.0 })
  }
  let scores = window_change_scores(values, min_segment=10)
  let changes = binary_segmentation(
    values,
    threshold=1.0,
    min_segment=10,
    max_changes=4,
  )
  assert_eq(scores.length(), 300)
  assert_true(changes.length() >= 1)
  assert_true(
    piecewise_constant_error(values, changes.map(fn(change) { change.index })) >=
    0.0,
  )
}

///|
test "threshold calibration handles a balanced labeled stream" {
  let observations : Array[ScoreObservation] = []
  for i in 0..<100 {
    observations.push(ScoreObservation::new(i.to_double() / 100.0, i >= 50))
  }
  let report = best_threshold(observations, threshold_grid(0.0, 1.0, 11))
  assert_true(report.f1 > 0.5)
  assert_true(report.precision >= 0.0 && report.recall >= 0.0)
}

///|
test "incident clustering handles a long alert burst" {
  let events : Array[AlertEvent] = []
  for i in 0..<50 {
    events.push(
      incident_event("api", i.to_int64(), if i % 10 == 0 { 1.0 } else { 0.7 }),
    )
  }
  let incidents = cluster_incidents(events, 2L)
  assert_true(incidents.length() <= 50)
  assert_eq(incident_alert_count(incidents), 50)
}

///|
test "SLO tracker aggregates a long quiet window" {
  let tracker = SloTracker::new(target=0.99)
  for _ in 0..<500 {
    tracker.observe(DetectionResult::quiet())
  }
  let report = tracker.close_period()
  assert_eq(report.availability(), 1.0)
  assert_true(!report.breached())
  assert_eq(tracker.periods(), 1)
}

///|
test "replay comparator validates repeated detector outputs" {
  let comparator = ReplayComparator::new()
  let detector = Cusum::new(control_limit=3.0)
  for i in 0..<32 {
    let expected = detector.update_result(
      if i < 16 {
        0.0
      } else {
        2.0
      },
      index=i,
    )
    let actual = DetectionResult::new(
      expected.changed,
      expected.score,
      expected.confidence,
      expected.direction,
      expected.index,
      evidence=expected.evidence,
    )
    assert_true(comparator.compare(expected, actual))
  }
  assert_eq(comparator.mismatches(), 0)
  assert_eq(comparator.compared(), 32)
}
