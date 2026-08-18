///|
test "ewma warms up then detects large residual" {
  let detector = EwmaDetector::new(alpha=0.1, threshold=3.0, warmup=3)
  for _ in 0..<8 {
    let result = detector.update(0.0)
    assert_eq(result.changed, false)
  }
  let result = detector.update(10.0)
  assert_eq(result.changed, true)
  assert_eq(direction_name(result.direction), "increase")
  assert_true(result.confidence > 0.0)
}

///|
test "ewma ignores non finite values" {
  let detector = EwmaDetector::new()
  let result = detector.update(0.0 / 0.0)
  assert_eq(result.changed, false)
  assert_eq(detector.baseline(), 0.0)
}

///|
test "robust z detects isolated outlier" {
  let detector = RobustZDetector::new(window_size=9, threshold=3.0)
  for _ in 0..<10 {
    ignore(detector.update(1.0))
  }
  let result = detector.update(20.0)
  assert_eq(result.changed, true)
  assert_eq(direction_name(result.direction), "increase")
}

///|
test "iqr detector detects both tails" {
  let detector = IqrSpikeDetector::new(window_size=9, multiplier=1.0)
  for _ in 0..<9 {
    ignore(detector.update(0.0))
  }
  assert_eq(detector.update(10.0).changed, true)
  let second = IqrSpikeDetector::new(window_size=9, multiplier=1.0)
  for _ in 0..<9 {
    ignore(second.update(0.0))
  }
  assert_eq(second.update(-10.0).changed, true)
}

///|
test "variance detector reacts to volatility increase" {
  let detector = VarianceShiftDetector::new(
    short_window=4,
    long_window=8,
    threshold=1.5,
  )
  for _ in 0..<12 {
    ignore(detector.update(0.0))
  }
  let mut changed = false
  for value in [5.0, -5.0, 5.0, -5.0, 5.0, -5.0] {
    if detector.update(value).changed {
      changed = true
    }
  }
  assert_eq(changed, true)
}

///|
test "trend detector needs persistence" {
  let detector = TrendShiftDetector::new(
    window_size=5,
    slope_threshold=0.5,
    persistence=2,
  )
  for value in [0.0, 0.1, 0.2, 0.3, 0.4] {
    ignore(detector.update(value))
  }
  let first = detector.update(5.0)
  assert_eq(first.changed, false)
  let second = detector.update(6.0)
  assert_eq(second.changed, true)
}

///|
test "rich legacy detector results carry evidence" {
  let detector = Cusum::new(control_limit=2.0, drift=0.1)
  let mut result = DetectionResult::quiet()
  for _ in 0..<5 {
    result = detector.update_result(2.0, index=1)
  }
  assert_true(result.evidence >= 0.0)
  let page = PageHinkley::new(control_limit=2.0, delta=0.1, alpha=0.9)
  let page_result = page.update_result(3.0, index=2)
  assert_true(page_result.score >= 0.0)
}

///|
test "adaptive baseline follows a slow change" {
  let baseline = AdaptiveBaseline::new(learning_rate=0.5)
  assert_eq(baseline.update(0.0), 0.0)
  assert_eq(baseline.update(2.0), 1.0)
  assert_true(baseline.update(2.0) > 1.0)
  assert_eq(baseline.sample_count(), 3)
}
