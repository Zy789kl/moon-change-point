///|
test "matrix identity and multiplication" {
  let identity = SquareMatrix::identity(2)
  let matrix = SquareMatrix::new(2)
  matrix.set(0, 0, 2.0)
  matrix.set(1, 1, 3.0)
  let product = identity.multiply(matrix)
  assert_eq(product.get(0, 0), 2.0)
  assert_eq(product.get(1, 1), 3.0)
  assert_eq(matrix.determinant(), 6.0)
}

///|
test "matrix transpose and quadratic form" {
  let matrix = SquareMatrix::new(2)
  matrix.set(0, 1, 2.0)
  matrix.set(1, 0, 3.0)
  assert_eq(matrix.transpose().get(0, 1), 3.0)
  assert_eq(matrix.quadratic_form([1.0, 1.0]), 5.0)
  matrix.regularize(1.0)
  assert_eq(matrix.get(0, 0), 1.0)
}

///|
test "matrix out of bounds access is safe" {
  let matrix = SquareMatrix::new(2)
  assert_eq(matrix.get(-1, 0), 0.0)
  assert_eq(matrix.get(2, 2), 0.0)
  matrix.set(2, 2, 9.0)
  assert_eq(matrix.diagonal(), [0.0, 0.0])
}

///|
test "reporting creates stable csv and markdown" {
  let result = DetectionResult::new(true, 2.0, 0.8, Unknown, 4, evidence=3.0)
  assert_true(detection_csv(result).contains("4,true"))
  assert_eq(
    detection_csv_header(),
    "index,changed,score,confidence,direction,evidence",
  )
  let point = ChangePoint::from_result(
    SignalPoint::new(5L, 2.0),
    result,
    "cpu",
    0.0,
  )
  assert_true(change_point_csv(point).contains("cpu"))
  assert_true(summary_markdown(StatsSummary::empty()).contains("count"))
  assert_true(
    metrics_markdown(ChangePointMetrics::empty()).contains("precision"),
  )
}

///|
test "reporting handles empty collections" {
  assert_true(results_csv([]).contains("index"))
  assert_true(changes_csv([]).contains("timestamp"))
  assert_true(alerts_markdown([]).contains("metric"))
}
