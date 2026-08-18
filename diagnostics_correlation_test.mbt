///|
test "window diagnosis recognizes a level increase" {
  let diagnostic = diagnose_windows([1.0, 1.0, 1.0], [5.0, 5.0, 5.0])
  assert_eq(diagnostic.before.mean, 1.0)
  assert_eq(diagnostic.after.mean, 5.0)
  assert_eq(direction_name(diagnostic_direction(diagnostic)), "increase")
  assert_true(diagnostic.actionable)
}

///|
test "window diagnosis recognizes a level decrease" {
  let diagnostic = diagnose_windows([5.0, 5.0], [1.0, 1.0])
  assert_eq(direction_name(diagnostic_direction(diagnostic)), "decrease")
  assert_true(diagnostic.mean_shift > 0.0)
}

///|
test "empty diagnostics are finite and non actionable" {
  let diagnostic = diagnose_windows([], [])
  assert_eq(diagnostic.mean_shift, 0.0)
  assert_eq(diagnostic.variance_ratio, 1.0)
  assert_true(!diagnostic.actionable)
  assert_true(diagnostic_markdown(diagnostic).contains("before mean"))
}

///|
test "diagnostic scores remain in the unit interval" {
  let diagnostic = diagnose_windows([0.0, 0.0], [100.0, 100.0])
  let score = diagnostic_score(diagnostic)
  assert_true(score >= 0.0 && score <= 1.0)
  assert_true(diagnostic_label(diagnostic).contains(":"))
}

///|
test "series diagnosis clamps split boundaries" {
  let left = diagnose_series([1.0, 1.0, 5.0, 5.0], -1)
  let right = diagnose_series([1.0, 1.0, 5.0, 5.0], 99)
  assert_true(left.before.count == 0)
  assert_true(right.after.count == 0)
}

///|
test "batch diagnostics keeps split order" {
  let result = diagnostics_batch([0.0, 0.0, 4.0, 4.0], [1, 2, 3])
  assert_eq(result.length(), 3)
  assert_eq(result[0].before.count, 1)
  assert_eq(result[2].after.count, 1)
  assert_true(actionable_diagnostics(result) >= 1)
}

///|
test "safe correlation handles constant vectors" {
  assert_eq(safe_correlation([1.0, 1.0], [2.0, 2.0]), 0.0)
  assert_true(safe_correlation([1.0, 2.0], [1.0, 2.0]) > 0.99)
}

///|
test "covariance matrix has the requested dimension" {
  let matrix = covariance_matrix([[1.0, 2.0], [2.0, 4.0]])
  assert_eq(matrix.size(), 2)
  assert_true(matrix.get(1, 1) >= matrix.get(0, 0))
}

///|
test "correlation matrix has unit diagonal" {
  let matrix = correlation_matrix([[1.0, 2.0], [2.0, 1.0]])
  assert_eq(matrix.get(0, 0), 1.0)
  assert_eq(matrix.get(1, 1), 1.0)
  assert_eq(matrix.get(0, 1), -1.0)
}

///|
test "pairwise correlation is empty safe" {
  assert_eq(average_pairwise_correlation([]), 0.0)
  assert_eq(average_pairwise_correlation([[1.0, 2.0]]), 0.0)
  assert_true(average_pairwise_correlation([[1.0, 2.0], [2.0, 4.0]]) > 0.9)
}

///|
test "lag correlation reports delayed relationship" {
  let left = [0.0, 1.0, 2.0, 3.0]
  let right = [1.0, 2.0, 3.0, 4.0]
  assert_true(lagged_correlation(left, right, 0) > 0.9)
  assert_eq(lagged_correlation(left, right, 99), 0.0)
  assert_true(best_lag(left, right, 2) >= 0)
}

///|
test "rolling correlation preserves aligned length" {
  let result = rolling_correlation([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], 2)
  assert_eq(result.length(), 3)
  assert_true(result[2] > 0.9)
}

///|
test "correlated change score and alert are deterministic" {
  let before = [[1.0, 2.0, 3.0], [1.0, 2.0, 3.0]]
  let after = [[3.0, 2.0, 1.0], [1.0, 2.0, 3.0]]
  let score = correlated_change_score(before, after)
  assert_true(score >= 0.0)
  let result = correlation_alert(before, after, threshold=0.0)
  assert_true(result.changed)
}
