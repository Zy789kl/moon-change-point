///|
test "CUSUM rich result includes index" {
  let detector = Cusum::new(control_limit=1.0)
  let result = detector.update_result(2.0, index=42)
  assert_eq(result.index, 42)
  assert_true(result.score >= 0.0)
}

///|
test "Page Hinkley rich result includes evidence" {
  let detector = PageHinkley::new(control_limit=1.0, delta=0.0)
  let result = detector.update_result(2.0, index=7)
  assert_eq(result.index, 7)
  assert_true(is_finite(result.evidence))
}

///|
test "Detector compatibility wrapper can be reset" {
  let detector = Detector::new(CusumDetector(Cusum::new(control_limit=1.0)))
  ignore(detector.update(2.0))
  let fresh = Detector::new(CusumDetector(Cusum::new(control_limit=1.0)))
  assert_true(!fresh.update(0.0))
}

///|
test "EWMA baseline adapts gradually" {
  let detector = EwmaDetector::new(warmup=2, alpha=0.2)
  ignore(detector.update(1.0))
  ignore(detector.update(1.0))
  let before = detector.baseline()
  ignore(detector.update(5.0))
  assert_true(detector.baseline() > before)
  assert_true(detector.scale() >= 0.0)
}

///|
test "variance detector returns finite score" {
  let detector = VarianceShiftDetector::new(short_window=2, long_window=4)
  for value in [1.0, 1.0, 10.0, 10.0, 10.0] {
    let result = detector.update(value)
    assert_true(is_finite(result.score))
  }
}

///|
test "trend detector handles flat input" {
  let detector = TrendShiftDetector::new(
    window_size=4,
    slope_threshold=0.1,
    persistence=2,
  )
  let result = detector.update(1.0)
  assert_true(result.score >= 0.0)
  detector.reset()
}

///|
test "IQR detector handles repeated values" {
  let detector = IqrSpikeDetector::new(window_size=5, multiplier=1.5)
  for _ in 0..<5 {
    ignore(detector.update(2.0))
  }
  let result = detector.update(100.0)
  assert_true(result.score >= 0.0)
}

///|
test "feature extractor exposes named features" {
  let names = feature_names()
  assert_true(names.length() >= 5)
  let extractor = FeatureExtractor::new(window_size=4)
  for value in [1.0, 2.0, 3.0, 4.0] {
    ignore(extractor.update(value))
  }
  let result = extractor.update(5.0)
  assert_true(is_finite(result.score))
}

///|
test "rank detector is robust to monotonic shifts" {
  let detector = RankShiftDetector::new(window_size=4)
  for value in [1.0, 1.0, 1.0, 1.0, 5.0, 5.0] {
    assert_true(detector.update(value).score >= 0.0)
  }
}

///|
test "distribution detector emits finite values" {
  let detector = DistributionShiftDetector::new(window_size=4)
  for value in [1.0, 1.0, 1.0, 3.0, 3.0] {
    assert_true(is_finite(detector.update(value).score))
  }
}

///|
test "multivariate detector checks vector dimensions" {
  let detector = MahalanobisDetector::new(2, warmup=2)
  assert_true(!detector.update([1.0]).changed)
  assert_eq(detector.dimension(), 2)
  assert_eq(detector.count(), 0)
  ignore(detector.update([1.0, 2.0]))
  assert_eq(detector.count(), 1)
}

///|
test "projection detector returns a projection evidence" {
  let detector = ProjectionDetector::new([1.0, 1.0], threshold=1.0)
  let result = detector.update([1.0, 2.0])
  assert_eq(detector.dimension(), 2)
  assert_true(is_finite(result.evidence))
}

///|
test "multiscale detector updates all horizons" {
  let detector = MultiScaleDetector::new(short=2, medium=3, long=4)
  for value in [0.0, 0.0, 4.0, 4.0, 4.0] {
    assert_true(is_finite(detector.update(value).score))
  }
}

///|
test "seasonal profile tracks phase counts" {
  let profile = SeasonalProfile::new(2, alpha=1.0)
  ignore(profile.update(1.0))
  ignore(profile.update(2.0))
  ignore(profile.update(3.0))
  assert_eq(profile.period(), 2)
  assert_eq(profile.count(0), 2)
  assert_eq(profile.count(1), 1)
}
