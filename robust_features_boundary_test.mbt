///|
test "winsorize keeps a copy and clamps both tails" {
  let input = [-100.0, 0.0, 1.0, 2.0, 100.0]
  let output = winsorize_robust(input, 0.2, 0.8)
  assert_eq(output.length(), input.length())
  assert_true(output[0] > input[0])
  assert_true(output[4] < input[4])
  assert_eq(input[0], -100.0)
}

///|
test "robust z score is safe for zero scale" {
  assert_eq(robust_z_score(3.0, 3.0, 0.0), 0.0)
  assert_eq(robust_z_score(8.0, 3.0, -1.0), 0.0)
  assert_eq(robust_z_score(8.0, 3.0, 2.0), 2.5)
}

///|
test "outlier mask marks the isolated tail" {
  let mask = outlier_mask([1.0, 1.0, 1.0, 1.0, 20.0], threshold=2.0)
  assert_eq(mask.length(), 5)
  assert_true(mask[4])
  assert_true(!mask[0])
}

///|
test "hampel filter protects a stable window" {
  let filtered = hampel_filter(
    [2.0, 2.0, 100.0, 2.0, 2.0],
    window_size=3,
    threshold=2.0,
  )
  assert_eq(filtered.length(), 5)
  assert_true(filtered[2] < 10.0)
  assert_eq(filtered[0], 2.0)
}

///|
test "clip values swaps inverted bounds" {
  let values = clip_values([-4.0, 0.0, 4.0], 2.0, -2.0)
  assert_eq(values, [-2.0, 0.0, 2.0])
}

///|
test "normalize range handles constants" {
  assert_eq(normalize_range([4.0, 4.0], minimum=10.0, maximum=20.0), [
    15.0, 15.0,
  ])
  assert_eq(normalize_range([], minimum=10.0, maximum=20.0), [])
  assert_eq(normalize_range([0.0, 5.0, 10.0]), [0.0, 0.5, 1.0])
}

///|
test "differences have mathematically defined lengths" {
  assert_eq(first_difference([]), [])
  assert_eq(first_difference([4.0]), [])
  assert_eq(first_difference([1.0, 4.0, 9.0]), [3.0, 5.0])
  assert_eq(second_difference([1.0, 4.0, 9.0]), [2.0])
}

///|
test "cumulative total preserves order" {
  assert_eq(cumulative_total([1.0, -1.0, 4.0]), [1.0, 0.0, 4.0])
  assert_eq(cumulative_total([]), [])
}

///|
test "lag values use zero warmup" {
  assert_eq(lag_values([1.0, 2.0, 3.0], 1), [0.0, 1.0, 2.0])
  assert_eq(lag_values([1.0, 2.0], 0), [1.0, 2.0])
  assert_eq(lag_values([1.0, 2.0], 5), [0.0, 0.0])
}

///|
test "rolling means and deviations preserve length" {
  let values = [1.0, 2.0, 3.0, 4.0]
  assert_eq(rolling_mean(values, 2).length(), values.length())
  assert_eq(rolling_standard_deviation(values, 2).length(), values.length())
  assert_eq(rolling_slope(values, 2).length(), values.length())
  assert_true(rolling_mean(values, 2)[3] > rolling_mean(values, 2)[0])
}

///|
test "rolling window one is accepted" {
  assert_eq(rolling_mean([2.0, 3.0], 0), [2.0, 3.0])
  assert_eq(rolling_standard_deviation([2.0, 3.0], 0), [0.0, 0.0])
}

///|
test "exponential smooth clamps rate" {
  assert_eq(exponential_smooth([1.0, 3.0], alpha=0.0), [1.0, 1.0])
  assert_eq(exponential_smooth([1.0, 3.0], alpha=1.0), [1.0, 3.0])
  assert_eq(exponential_smooth([], alpha=0.5), [])
}

///|
test "forward fill uses fallback before first valid point" {
  let values = forward_fill([0.0 / 0.0, 3.0, 0.0 / 0.0], fallback=7.0)
  assert_eq(values, [7.0, 3.0, 3.0])
}

///|
test "robust scale falls back when MAD is zero" {
  assert_eq(robust_scale([5.0, 5.0, 5.0]), 0.0)
  assert_true(robust_scale([1.0, 2.0, 3.0]) > 0.0)
}
