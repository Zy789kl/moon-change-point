///|
test "stats empty and singleton boundaries" {
  assert_eq(mean([]), 0.0)
  assert_eq(variance([]), 0.0)
  assert_eq(median([]), 0.0)
  assert_eq(array_minimum([]), 0.0)
  assert_eq(array_maximum([]), 0.0)
  assert_eq(mean([7.0]), 7.0)
  assert_eq(variance([7.0]), 0.0)
  assert_eq(quantile([7.0], 0.0), 7.0)
  assert_eq(quantile([7.0], 1.0), 7.0)
}

///|
test "stats quantiles are bounded" {
  let values = [1.0, 2.0, 3.0, 4.0, 5.0]
  assert_eq(median(values), 3.0)
  assert_eq(quantile(values, -1.0), 1.0)
  assert_eq(quantile(values, 2.0), 5.0)
  assert_eq(percentile(values, 25.0), 2.0)
  assert_eq(percentile(values, 75.0), 4.0)
  assert_eq(interquartile_range(values), 2.0)
}

///|
test "stats robust estimators resist a spike" {
  let values = [1.0, 1.0, 1.1, 0.9, 1.0, 100.0]
  assert_true(median(values) < 2.0)
  assert_true(median_absolute_deviation(values) < 0.2)
  assert_true(trimmed_mean(values, 0.2) < 2.0)
}

///|
test "stats online moments match batch moments" {
  let values = [2.0, 4.0, 6.0, 8.0]
  let moments = OnlineMoments::new()
  for value in values {
    moments.push(value)
  }
  assert_eq(moments.count(), 4)
  assert_true(absolute(moments.mean() - mean(values)) < 1.0e-12)
  assert_true(
    absolute(moments.population_variance() - variance(values)) < 1.0e-12,
  )
  assert_eq(moments.minimum(), 2.0)
  assert_eq(moments.maximum(), 8.0)
}

///|
test "stats merge preserves moments" {
  let left = OnlineMoments::new()
  let right = OnlineMoments::new()
  for value in [1.0, 2.0, 3.0] {
    left.push(value)
  }
  for value in [4.0, 5.0, 6.0] {
    right.push(value)
  }
  left.merge(right)
  assert_eq(left.count(), 6)
  assert_true(absolute(left.mean() - 3.5) < 1.0e-12)
  assert_true(
    absolute(
      left.population_variance() - variance([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]),
    ) <
    1.0e-12,
  )
}

///|
test "stats association functions handle constants" {
  assert_eq(covariance([1.0, 1.0], [2.0, 3.0]), 0.0)
  assert_eq(correlation([1.0, 1.0], [2.0, 3.0]), 0.0)
  assert_eq(autocorrelation([1.0, 1.0, 1.0], 1), 0.0)
  assert_eq(linear_slope([4.0, 4.0, 4.0]), 0.0)
  assert_eq(mean_absolute_difference([4.0]), 0.0)
}

///|
test "stats weighted mean ignores negative weights" {
  assert_true(
    absolute(weighted_mean([10.0, 20.0], [1.0, -1.0]) - 10.0) < 1.0e-12,
  )
  assert_eq(weighted_mean([10.0], [0.0]), 0.0)
}

///|
test "stats sorting is stable enough for duplicates" {
  let sorted = sorted_copy([3.0, 1.0, 2.0, 1.0])
  assert_eq(sorted[0], 1.0)
  assert_eq(sorted[1], 1.0)
  assert_eq(sorted[2], 2.0)
  assert_eq(sorted[3], 3.0)
}

///|
test "stats finite guards reject nan and infinities" {
  assert_eq(is_finite(1.0), true)
  assert_eq(is_finite(0.0 / 0.0), false)
  let moments = OnlineMoments::new()
  moments.push(0.0 / 0.0)
  assert_eq(moments.count(), 0)
}

///|
test "stats summary exposes all key fields" {
  let moments = OnlineMoments::new()
  for value in [1.0, 3.0, 5.0] {
    moments.push(value)
  }
  let summary = moments.summary(median=3.0)
  assert_eq(summary.count, 3)
  assert_eq(summary.mean, 3.0)
  assert_eq(summary.median, 3.0)
  assert_eq(summary.minimum, 1.0)
  assert_eq(summary.maximum, 5.0)
}
