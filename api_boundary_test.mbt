///|
test "public result constructors clamp unsafe values" {
  let result = DetectionResult::new(true, -1.0, 4.0, Unknown, -2, evidence=-3.0)
  assert_eq(result.score, 0.0)
  assert_eq(result.confidence, 1.0)
  assert_eq(result.index, -2)
  assert_eq(result.evidence, -3.0)
}

///|
test "severity and direction labels are stable" {
  assert_eq(severity_name(severity_from_score(0.1)), "informational")
  assert_eq(severity_name(severity_from_score(0.7)), "warning")
  assert_eq(severity_name(severity_from_score(1.0)), "critical")
  assert_eq(direction_name(Unknown), "unknown")
}

///|
test "change point summaries include detector context" {
  let result = DetectionResult::new(true, 2.0, 0.9, Unknown, 3)
  let point = ChangePoint::from_result(
    SignalPoint::new(100L, 4.0),
    result,
    "service",
    1.0,
  )
  assert_true(point.summary().contains("service"))
  assert_true(result.summary().contains("score"))
}

///|
test "legacy detector wrapper keeps boolean compatibility" {
  let detector = Detector::new(
    CusumDetector(Cusum::new(control_limit=1.0, drift=0.1)),
    suppression_limit=0,
  )
  let mut changed = false
  for _ in 0..<4 {
    if detector.update(2.0) {
      changed = true
    }
  }
  assert_eq(changed, true)
}

///|
test "bayesian result confidence is a probability" {
  let detector = Bayesian::new(hazard_rate=0.1, max_run_length=8)
  let result = detector.update_result(1.0, index=1)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.score >= 0.0)
}
