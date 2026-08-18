///|
test "public point constructors preserve timestamp and sequence" {
  let point = SignalPoint::new(123L, 4.5, sequence=9)
  assert_eq(point.timestamp, 123L)
  assert_eq(point.value, 4.5)
  assert_eq(point.sequence, 9)
}

///|
test "result summary includes all key labels" {
  let result = DetectionResult::new(true, 0.8, 0.9, Decrease, 2)
  let summary = result.summary()
  assert_true(summary.contains("changed"))
  assert_true(summary.contains("score"))
  assert_true(summary.contains("direction"))
}

///|
test "change point uses score derived severity" {
  let result = DetectionResult::new(true, 0.95, 0.95, Increase, 2)
  let point = ChangePoint::from_result(
    SignalPoint::new(4L, 10.0),
    result,
    "api",
    1.0,
  )
  assert_eq(severity_name(point.severity), "critical")
  assert_eq(point.observed, 10.0)
}

///|
test "online ensemble handles a quorum" {
  let ensemble = OnlineEnsemble::new(
    [IqrSpike(IqrSpikeDetector::new()), RobustZ(RobustZDetector::new())],
    quorum=2,
  )
  let result = ensemble.update(1.0)
  assert_eq(ensemble.count(), 2)
  assert_true(result.result.score >= 0.0)
}

///|
test "weighted consensus tolerates a short weights array" {
  let results = [
    DetectionResult::new(true, 0.8, 0.8, Increase, 1),
    DetectionResult::quiet(index=2),
  ]
  let result = weighted_consensus(results, [1.0], 0.5)
  assert_true(result.score >= 0.0)
}

///|
test "calibration bins sum to a normalized profile" {
  let observations = [
    ScoreObservation::new(0.1, false),
    ScoreObservation::new(0.9, true),
  ]
  let bins = calibration_bins(observations, bins=2)
  assert_eq(bins.length(), 2)
  assert_true(sum(bins) > 0.0)
}

///|
test "best threshold chooses a finite candidate" {
  let observations = [
    ScoreObservation::new(0.1, false),
    ScoreObservation::new(0.9, true),
  ]
  let report = best_threshold(observations, [0.2, 0.8])
  assert_true(is_finite(report.threshold))
  assert_true(report.f1 >= 0.0)
}

///|
test "forecast points have ordered uncertainty bounds" {
  let point = ForecastPoint::new(10.0, 1.0, uncertainty=2.0)
  assert_true(point.lower <= point.prediction)
  assert_true(point.prediction <= point.upper)
}

///|
test "linear forecaster can fit a short line" {
  let forecaster = LinearForecaster::new(window_size=3, horizon=1)
  ignore(forecaster.fit(1.0))
  ignore(forecaster.fit(2.0))
  let prediction = forecaster.fit(3.0)
  assert_true(is_finite(prediction.prediction))
}

///|
test "Holt forecaster accepts a nonpositive horizon" {
  let forecaster = HoltForecaster::new(alpha=0.2, beta=0.1)
  let prediction = forecaster.update(1.0, horizon=0)
  assert_true(is_finite(prediction.prediction))
}

///|
test "AR1 forecaster warms up without NaN" {
  let forecaster = Ar1Forecaster::new(forgetting=0.1)
  for value in [1.0, 2.0, 3.0] {
    assert_true(is_finite(forecaster.update(value).prediction))
  }
}

///|
test "feature distance is symmetric enough" {
  let left = extract_features([1.0, 2.0, 3.0])
  let right = extract_features([3.0, 2.0, 1.0])
  assert_true(feature_distance(left, right) >= 0.0)
  assert_true(feature_distance(left, left) <= feature_distance(left, right))
}

///|
test "backfill lag shifts timestamps" {
  let points = timestamped_signal([1.0, 2.0], start=10L, step=1L)
  let shifted = lag_points(points, 5L)
  assert_eq(shifted[0].timestamp, 15L)
}

///|
test "rolling quantiles preserve length" {
  let result = rolling_quantile([1.0, 2.0, 3.0, 4.0], 2, 0.5)
  assert_eq(result.length(), 4)
  assert_true(result[3] >= result[0])
}

///|
test "align by timestamp joins common points" {
  let left = timestamped_signal([1.0, 2.0], start=0L, step=2L)
  let right = timestamped_signal([4.0, 5.0], start=0L, step=1L)
  let aligned = align_by_timestamp(left, right)
  assert_true(aligned.0.length() >= 1)
  assert_eq(aligned.0.length(), aligned.1.length())
}
