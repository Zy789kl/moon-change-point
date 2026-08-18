///|
test "online moments starts empty" {
  let moments = OnlineMoments::new()
  assert_eq(moments.count(), 0)
  assert_eq(moments.mean(), 0.0)
  assert_eq(moments.variance(), 0.0)
}

///|
test "online moments ignores non finite input" {
  let moments = OnlineMoments::new()
  moments.push(0.0 / 0.0)
  moments.push(1.0)
  assert_eq(moments.count(), 1)
  assert_eq(moments.mean(), 1.0)
}

///|
test "online moments follows Welford on two values" {
  let moments = OnlineMoments::new()
  moments.push(1.0)
  moments.push(3.0)
  assert_eq(moments.mean(), 2.0)
  assert_eq(moments.population_variance(), 1.0)
  assert_eq(moments.variance(), 2.0)
}

///|
test "online moments merge is associative enough" {
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
  assert_eq(left.mean(), 3.5)
}

///|
test "prior moments use effective sample size" {
  let moments = OnlineMoments::with_prior(4.0, 2.0, 3)
  assert_eq(moments.count(), 3)
  assert_eq(moments.mean(), 4.0)
  assert_eq(moments.population_variance(), 2.0)
}

///|
test "sorted copy preserves input" {
  let values = [3.0, 1.0, 2.0]
  assert_eq(sorted_copy(values), [1.0, 2.0, 3.0])
  assert_eq(values, [3.0, 1.0, 2.0])
}

///|
test "quantile clamps probabilities" {
  let values = [1.0, 2.0, 3.0]
  assert_eq(quantile(values, -1.0), 1.0)
  assert_eq(quantile(values, 2.0), 3.0)
  assert_eq(median(values), 2.0)
}

///|
test "trimmed mean falls back to median for excessive trim" {
  assert_eq(trimmed_mean([1.0, 2.0, 100.0], 0.9), 2.0)
  assert_eq(trimmed_mean([], 0.5), 0.0)
}

///|
test "weighted mean ignores negative weights" {
  assert_eq(weighted_mean([1.0, 10.0], [1.0, -1.0]), 1.0)
  assert_eq(weighted_mean([1.0], [0.0]), 0.0)
}

///|
test "covariance and correlation handle unequal lengths" {
  assert_true(covariance([1.0, 2.0, 3.0], [1.0, 2.0]) >= 0.0)
  assert_true(correlation([1.0, 2.0, 3.0], [1.0, 2.0]) >= 0.0)
}

///|
test "linear slope identifies direction" {
  assert_true(linear_slope([1.0, 2.0, 3.0]) > 0.0)
  assert_true(linear_slope([3.0, 2.0, 1.0]) < 0.0)
  assert_eq(linear_slope([1.0]), 0.0)
}

///|
test "autocorrelation handles invalid lags" {
  assert_eq(autocorrelation([1.0, 2.0], 0), 0.0)
  assert_eq(autocorrelation([1.0, 2.0], 2), 0.0)
  assert_true(autocorrelation([1.0, 2.0, 1.0], 1) < 0.0)
}

///|
test "array extrema are safe on empty arrays" {
  assert_eq(array_minimum([]), 0.0)
  assert_eq(array_maximum([]), 0.0)
  assert_eq(sum([]), 0.0)
}

///|
test "summary stores median and extrema" {
  let moments = OnlineMoments::new()
  for value in [1.0, 2.0, 4.0] {
    moments.push(value)
  }
  let result = moments.summary(median=2.0)
  assert_eq(result.count, 3)
  assert_eq(result.minimum, 1.0)
  assert_eq(result.maximum, 4.0)
  assert_eq(result.median, 2.0)
}

///|
test "absolute sign and finite helpers are total" {
  assert_eq(absolute(-2.0), 2.0)
  assert_eq(sign(-2.0), -1)
  assert_eq(sign(0.0), 0)
  assert_eq(sign(2.0), 1)
  assert_true(!is_finite(0.0 / 0.0))
}
