///|
test "multi scale detector returns consensus evidence" {
  let detector = MultiScaleDetector::new(
    short=4,
    medium=8,
    long=12,
    minimum_consensus=0.0,
  )
  let mut result = DetectionResult::quiet()
  for _ in 0..<20 {
    result = detector.update(0.0)
  }
  assert_true(result.evidence >= 0.0)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
}

///|
test "scale profile is produced for every requested scale" {
  let profile = scale_profile([0.0, 1.0, 2.0, 3.0], [2, 3, 4])
  assert_eq(profile.length(), 3)
  for item in profile {
    assert_true(item.consensus >= 0.0 && item.consensus <= 1.0)
  }
  assert_true(
    adaptive_threshold([0.1, 0.2, 0.9], false_positive_rate=0.1) >= 0.0,
  )
}

///|
test "online ensemble applies quorum" {
  let ensemble = OnlineEnsemble::new(
    [Ewma(EwmaDetector::new()), RobustZ(RobustZDetector::new())],
    quorum=2,
  )
  assert_eq(ensemble.count(), 2)
  let result = ensemble.update(0.0)
  assert_eq(result.detector_count, 2)
  assert_true(result.agreement >= 0.0)
}

///|
test "weighted consensus combines confidence" {
  let first = DetectionResult::new(true, 2.0, 0.8, Unknown, 1)
  let second = DetectionResult::new(false, 1.0, 0.2, Unknown, 1)
  let result = weighted_consensus([first, second], [2.0, 1.0], 0.5)
  assert_eq(result.changed, true)
  assert_true(result.confidence > 0.0)
  assert_true(detector_reliability([first, second]) > 0.0)
}

///|
test "consensus score handles empty and mixed results" {
  assert_eq(consensus_score([]), 0.0)
  let results = [
    DetectionResult::new(true, 1.0, 1.0, Unknown, 1),
    DetectionResult::quiet(index=1),
  ]
  assert_eq(consensus_score(results), 0.5)
}
