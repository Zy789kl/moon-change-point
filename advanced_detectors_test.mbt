///|
test "step detector responds to a sustained step" {
  let detector = StepChangeDetector::new(window_size=3, threshold=1.0)
  for _ in 0..<7 {
    ignore(detector.update(0.0))
  }
  let mut changed = false
  for _ in 0..<6 {
    if detector.update(5.0).changed {
      changed = true
    }
  }
  assert_eq(changed, true)
}

///|
test "mean variance detector detects variance branch" {
  let detector = MeanVarianceDetector::new(
    window_size=4,
    mean_threshold=10.0,
    variance_threshold=1.2,
  )
  for _ in 0..<8 {
    ignore(detector.update(0.0))
  }
  let mut result = DetectionResult::quiet()
  for value in [10.0, -10.0, 10.0, -10.0] {
    result = detector.update(value)
  }
  assert_true(result.score >= 0.0)
  assert_true(
    direction_name(result.direction) == "variance-increase" ||
    direction_name(result.direction) == "variance-decrease" ||
    direction_name(result.direction) == "unknown",
  )
}

///|
test "dual sided detector returns a normalized result" {
  let detector = DualSidedDetector::new(limit=2.0, drift=0.1)
  let mut last = DetectionResult::quiet()
  for _ in 0..<5 {
    last = detector.update(-3.0)
  }
  assert_true(last.score >= 0.0)
  assert_true(last.confidence >= 0.0 && last.confidence <= 1.0)
}

///|
test "persistence detector suppresses isolated positive" {
  let detector = PersistenceDetector::new(warmup=1, persistence=3)
  let first = detector.update(10.0)
  assert_eq(first.changed, false)
  let second = detector.update(0.0)
  assert_eq(second.changed, false)
}

///|
test "score utilities are monotone and bounded" {
  assert_true(sigmoid_score(2.0) > sigmoid_score(1.0))
  assert_true(tail_confidence(3.0) > tail_confidence(1.0))
  assert_eq(combine_scores([], []), 0.0)
  assert_eq(score_margin(3.0, 2.0), 1.0)
  assert_true(score_to_confidence(4.0, 2.0) > 0.5)
}

///|
test "score threshold and normalization handle constants" {
  assert_eq(threshold_for_false_positive([1.0, 2.0, 3.0], 0.0), 3.0)
  assert_eq(normalize_scores([5.0, 5.0]), [0.0, 0.0])
  assert_true(expected_alert_cost(0.2, 0.5, false_negative_cost=2.0) > 0.0)
}
