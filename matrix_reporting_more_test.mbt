///|
test "identity matrix is diagonal" {
  let matrix = SquareMatrix::identity(3)
  assert_eq(matrix.size(), 3)
  assert_eq(matrix.get(0, 0), 1.0)
  assert_eq(matrix.get(0, 1), 0.0)
  assert_eq(matrix.get(2, 2), 1.0)
}

///|
test "matrix transpose swaps off diagonal values" {
  let matrix = SquareMatrix::new(2)
  matrix.set(0, 1, 4.0)
  let transposed = matrix.transpose()
  assert_eq(transposed.get(1, 0), 4.0)
  assert_eq(transposed.get(0, 1), 0.0)
}

///|
test "matrix addition and scale compose" {
  let left = SquareMatrix::identity(2)
  let right = SquareMatrix::identity(2)
  let sum_matrix = left.add(right).scale(0.5)
  assert_eq(sum_matrix.get(0, 0), 1.0)
  assert_eq(sum_matrix.get(1, 1), 1.0)
}

///|
test "matrix multiplication preserves identity" {
  let matrix = SquareMatrix::new(2)
  matrix.set(0, 0, 2.0)
  matrix.set(1, 1, 3.0)
  let product = matrix.multiply(SquareMatrix::identity(2))
  assert_eq(product.get(0, 0), 2.0)
  assert_eq(product.get(1, 1), 3.0)
}

///|
test "quadratic form and Mahalanobis score are non negative" {
  let matrix = SquareMatrix::identity(2)
  assert_eq(matrix.quadratic_form([2.0, 3.0]), 13.0)
  assert_true(diagonal_mahalanobis([2.0, 3.0], [0.0, 0.0], [1.0, 1.0]) > 0.0)
}

///|
test "matrix regularization changes the diagonal" {
  let matrix = SquareMatrix::new(2)
  matrix.regularize(0.1)
  assert_eq(matrix.get(0, 0), 0.1)
  assert_eq(matrix.get(1, 1), 0.1)
}

///|
test "detection CSV has stable headers" {
  let result = DetectionResult::new(true, 0.8, 0.7, Increase, 3, evidence=2.0)
  assert_true(detection_csv_header().contains("changed"))
  assert_true(detection_csv(result).contains("3,true"))
  assert_true(results_csv([result]).contains("index,changed"))
}

///|
test "change point CSV includes detector name" {
  let result = DetectionResult::new(true, 0.8, 0.7, Increase, 3)
  let point = ChangePoint::from_result(
    SignalPoint::new(9L, 4.0),
    result,
    "latency",
    1.0,
  )
  assert_true(change_point_csv_header().contains("detector"))
  assert_true(change_point_csv(point).contains("latency"))
}

///|
test "summary markdown includes all summary fields" {
  let summary = StatsSummary::empty()
  let markdown = summary_markdown(summary)
  assert_true(markdown.contains("count"))
  assert_true(markdown.contains("mean"))
  assert_true(markdown.contains("variance"))
}

///|
test "metrics markdown includes F1" {
  let metrics = ChangePointMetrics::empty()
  assert_true(metrics_markdown(metrics).contains("F1"))
}

///|
test "alerts markdown works for empty input" {
  assert_true(alerts_markdown([]).contains("metric"))
  assert_true(alerts_markdown([]).contains("suppressed"))
}

///|
test "direction labels cover all operational modes" {
  assert_eq(direction_name(Increase), "increase")
  assert_eq(direction_name(Decrease), "decrease")
  assert_eq(direction_name(VarianceIncrease), "variance-increase")
  assert_eq(direction_name(VarianceDecrease), "variance-decrease")
  assert_eq(direction_name(DistributionShift), "distribution-shift")
}

///|
test "severity thresholds are ordered" {
  assert_eq(severity_name(severity_from_score(0.0)), "informational")
  assert_eq(severity_name(severity_from_score(0.6)), "warning")
  assert_eq(severity_name(severity_from_score(0.9)), "critical")
}

///|
test "result constructor sanitizes NaN score" {
  let result = DetectionResult::new(true, 0.0 / 0.0, 0.5, Unknown, 0)
  assert_eq(result.score, 0.0)
  assert_true(is_finite(result.score))
}

///|
test "alert event constructor preserves ordinal" {
  let point = ChangePoint::from_result(
    SignalPoint::new(1L, 1.0),
    DetectionResult::quiet(),
    "x",
    1.0,
  )
  let event = AlertEvent::new("x", point, suppressed=true, ordinal=4)
  assert_true(event.suppressed)
  assert_eq(event.ordinal, 4)
}
