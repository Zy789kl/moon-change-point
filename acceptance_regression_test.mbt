///|
test "CUSUM remains quiet during a stationary baseline" {
  let detector = Cusum::new(target_mean=10.0, control_limit=5.0, drift=0.25)
  let mut alerts = 0
  for _ in 0..<100 {
    if detector.update(10.0) {
      alerts += 1
    }
  }
  assert_eq(alerts, 0)
}

///|
test "CUSUM detects a sustained positive shift" {
  let detector = Cusum::new(target_mean=0.0, control_limit=2.0, drift=0.1)
  let mut detected = false
  for _ in 0..<40 {
    if detector.update(1.0) {
      detected = true
    }
  }
  assert_true(detected)
}

///|
test "Page Hinkley reset clears a previous signal" {
  let detector = PageHinkley::new(delta=0.0, control_limit=1.0)
  for _ in 0..<20 {
    ignore(detector.update(10.0))
  }
  detector.reset()
  assert_true(!detector.update(0.0))
}

///|
test "Bayesian detector output is bounded for extremes" {
  let detector = Bayesian::new(hazard_rate=0.2, max_run_length=16)
  for i in 0..<20 {
    let result = detector.update_result(
      if i % 2 == 0 {
        -1000.0
      } else {
        1000.0
      },
      index=i,
    )
    assert_true(result.score >= 0.0)
    assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
    assert_true(is_finite(result.score) && is_finite(result.confidence))
  }
}

///|
test "adaptive detectors handle non finite input" {
  let ewma = EwmaDetector::new()
  let robust = RobustZDetector::new()
  let result1 = ewma.update(0.0 / 0.0)
  let result2 = robust.update(0.0 / 0.0)
  assert_true(!result1.changed)
  assert_true(!result2.changed)
}

///|
test "persistence detector requires consecutive evidence" {
  let detector = PersistenceDetector::new(warmup=0, persistence=3)
  let mut last = DetectionResult::quiet()
  for value in [0.0, 10.0, 0.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0] {
    last = detector.update(value)
  }
  assert_true(last.index > 0)
  assert_true(last.score >= 0.0)
}

///|
test "multi scale profile is empty safe" {
  assert_eq(scale_profile([], [2, 4]).length(), 2)
  assert_eq(consensus_score([]), 0.0)
  assert_true(adaptive_threshold([0.1, 0.2, 0.3]) >= 0.0)
}

///|
test "ensemble reliability is stable for quiet results" {
  let results = [
    DetectionResult::quiet(index=0),
    DetectionResult::quiet(index=1),
  ]
  assert_eq(detector_reliability(results), 0.0)
  assert_eq(consensus_score(results), 0.0)
}

///|
test "offline metrics cover perfect and empty matches" {
  let perfect = evaluate_change_points([10, 20], [10, 20], tolerance=0)
  assert_eq(perfect.f1, 1.0)
  let empty = evaluate_change_points([], [], tolerance=3)
  assert_eq(empty.precision, 1.0)
  assert_eq(empty.recall, 1.0)
}

///|
test "segmentation does not invent a boundary in a constant series" {
  let changes = binary_segmentation(
    Array::make(40, 2.0),
    threshold=1.0,
    min_segment=3,
    max_changes=5,
  )
  assert_eq(changes.length(), 0)
  assert_eq(best_boundary(Array::make(20, 2.0), minimum_segment=3), 3)
}

///|
test "quality gate rejects incomplete data" {
  let values = [1.0, 0.0 / 0.0, 1.0, 0.0 / 0.0]
  let report = validate_values(values)
  assert_eq(report.non_finite, 2)
  assert_true(!DataQualityGate::new(minimum_ratio=0.75).accept(report))
}

///|
test "matrix determinant covers two by two matrices" {
  let matrix = SquareMatrix::new(2)
  matrix.set(0, 0, 2.0)
  matrix.set(0, 1, 1.0)
  matrix.set(1, 0, 1.0)
  matrix.set(1, 1, 2.0)
  assert_eq(matrix.determinant(), 3.0)
  assert_eq(matrix.diagonal(), [2.0, 2.0])
}

///|
test "forecast metrics ignore zero denominators" {
  assert_eq(forecast_mae([], []), 0.0)
  assert_eq(forecast_rmse([0.0], [0.0]), 0.0)
  assert_eq(forecast_mape([0.0], [1.0]), 0.0)
}

///|
test "seasonal naive forecast returns requested horizon" {
  let forecast = seasonal_naive_forecast([1.0, 2.0, 3.0], 2, 5)
  assert_eq(forecast.length(), 5)
  assert_eq(seasonal_naive_forecast([], 2, 5), [])
}

///|
test "histogram normalizes counts" {
  let histogram = Histogram::new(0.0, 10.0, 5)
  for value in [0.0, 1.0, 5.0, 9.9, 10.0] {
    histogram.push(value)
  }
  assert_eq(histogram.total(), 5)
  assert_eq(histogram.counts().length(), 5)
  assert_true(histogram.probabilities()[0] >= 0.0)
}
