///|
test "histogram probabilities sum to one" {
  let histogram = Histogram::new(0.0, 10.0, 5)
  for value in [0.0, 1.0, 2.0, 8.0, 10.0] {
    histogram.push(value)
  }
  assert_eq(histogram.total(), 5)
  assert_true(absolute(sum(histogram.probabilities()) - 1.0) < 1.0e-12)
  histogram.reset()
  assert_eq(histogram.total(), 0)
}

///|
test "distribution distances separate different samples" {
  assert_eq(ks_statistic([], [1.0]), 0.0)
  assert_true(ks_statistic([0.0, 0.0], [1.0, 1.0]) > 0.9)
  assert_true(
    histogram_hellinger(
      Histogram::new(0.0, 1.0, 4),
      Histogram::new(0.0, 1.0, 4),
    ) ==
    0.0,
  )
  assert_true(distribution_change_score([0.0, 0.0], [5.0, 5.0]) > 0.0)
}

///|
test "distribution detector waits for two complete windows" {
  let detector = DistributionShiftDetector::new(window_size=3, threshold=0.1)
  for _ in 0..<5 {
    assert_eq(detector.update(0.0).changed, false)
  }
  let mut changed = false
  for _ in 0..<5 {
    if detector.update(10.0).changed {
      changed = true
    }
  }
  assert_eq(changed, true)
}

///|
test "seasonal profile and naive forecast are bounded" {
  let profile = SeasonalProfile::new(3, alpha=1.0)
  for value in [1.0, 2.0, 3.0, 1.0, 2.0, 3.0] {
    ignore(profile.update(value))
  }
  assert_eq(profile.period(), 3)
  assert_eq(profile.levels(), [1.0, 2.0, 3.0])
  assert_eq(seasonal_naive_forecast([1.0, 2.0, 3.0], 3, 4), [1.0, 2.0, 3.0, 1.0])
  assert_true(seasonal_strength([1.0, 2.0, 3.0, 1.0, 2.0, 3.0], 3) > 0.9)
}

///|
test "seasonal detector accepts finite and rejects invalid" {
  let detector = SeasonalAnomalyDetector::new(2, threshold=1.0)
  assert_eq(detector.update(0.0 / 0.0).changed, false)
  for value in [1.0, 1.0, 1.0, 1.0] {
    ignore(detector.update(value))
  }
  assert_eq(detector.update(10.0).changed, true)
}
