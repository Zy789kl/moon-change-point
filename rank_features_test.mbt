///|
test "rank and effect sizes have expected signs" {
  assert_eq(ranks([3.0, 1.0, 2.0]), [3.0, 1.0, 2.0])
  assert_true(spearman_correlation([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]) > 0.99)
  assert_true(mann_whitney_u([3.0, 4.0], [1.0, 2.0]) > 0.0)
  assert_true(rank_biserial_effect([3.0, 4.0], [1.0, 2.0]) > 0.0)
}

///|
test "rank tests handle ties and short data" {
  assert_eq(ranks([1.0, 1.0]), [1.0, 1.0])
  assert_eq(sign_change_rate([]), 0.0)
  assert_eq(runs_test_score([1.0]), 0.0)
  assert_true(slope_confidence([0.0, 1.0, 2.0]) > 0.0)
}

///|
test "rank shift detector is quiet during warmup" {
  let detector = RankShiftDetector::new(window_size=4, threshold=0.2)
  for _ in 0..<7 {
    assert_eq(detector.update(0.0).changed, false)
  }
  let mut changed = false
  for _ in 0..<5 {
    if detector.update(5.0).changed {
      changed = true
    }
  }
  assert_eq(changed, true)
}

///|
test "features expose stable names and empty behavior" {
  let empty = extract_features([])
  assert_eq(empty.count, 0)
  assert_eq(feature_names().length(), 11)
  let features = extract_features([1.0, 2.0, 3.0, 4.0])
  assert_eq(features.count, 4)
  assert_eq(features.minimum, 1.0)
  assert_eq(features.maximum, 4.0)
  assert_true(features.slope > 0.0)
}

///|
test "feature distance is symmetric and nonnegative" {
  let left = [1.0, 1.0, 1.0]
  let right = [2.0, 2.0, 2.0]
  assert_eq(feature_change_score(left, left), 0.0)
  assert_true(feature_change_score(left, right) >= 0.0)
  assert_true(
    absolute(
      feature_change_score(left, right) - feature_change_score(right, left),
    ) <
    1.0e-12,
  )
}

///|
test "feature extractor compares adjacent windows" {
  let detector = FeatureExtractor::new(window_size=3, threshold=0.05)
  for _ in 0..<6 {
    ignore(detector.update(0.0))
  }
  let mut changed = false
  for _ in 0..<5 {
    if detector.update(4.0).changed {
      changed = true
    }
  }
  assert_eq(changed, true)
}
