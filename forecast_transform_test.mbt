///|
test "linear forecaster emits interval and learns slope" {
  let forecaster = LinearForecaster::new(window_size=4, horizon=1)
  ignore(forecaster.fit(0.0))
  ignore(forecaster.fit(1.0))
  ignore(forecaster.fit(2.0))
  let result = forecaster.fit(3.0)
  assert_true(result.prediction >= 2.0)
  assert_true(result.lower <= result.prediction)
  assert_true(result.upper >= result.prediction)
}

///|
test "holt forecaster handles initialization and missing value" {
  let forecaster = HoltForecaster::new(alpha=0.5, beta=0.2)
  assert_eq(forecaster.update(3.0).prediction, 3.0)
  let second = forecaster.update(5.0)
  assert_true(second.prediction >= 3.0)
  assert_true(is_finite(forecaster.update(0.0 / 0.0).prediction))
}

///|
test "ar1 forecaster remains finite" {
  let forecaster = Ar1Forecaster::new(forgetting=0.2)
  for value in [1.0, 1.1, 0.9, 1.2, 1.0] {
    let result = forecaster.update(value)
    assert_true(is_finite(result.prediction))
  }
}

///|
test "forecast error metrics align lengths" {
  assert_eq(forecast_mae([], []), 0.0)
  assert_eq(forecast_rmse([1.0, 2.0], [1.0]), 0.0)
  assert_eq(forecast_mape([0.0], [1.0]), 0.0)
  assert_true(forecast_rmse([0.0, 2.0], [1.0, 1.0]) > 0.0)
}

///|
test "transform functions preserve expected shapes" {
  assert_eq(difference([1.0, 3.0, 6.0], lag=1), [2.0, 3.0])
  assert_eq(cumulative_sum([1.0, 2.0, 3.0]), [1.0, 3.0, 6.0])
  assert_eq(moving_average([1.0, 3.0, 5.0], 2), [1.0, 2.0, 4.0])
  assert_eq(moving_median([1.0, 3.0, 5.0], 2), [1.0, 2.0, 4.0])
  assert_eq(downsample_mean([1.0, 2.0, 3.0, 4.0, 5.0], 2), [1.5, 3.5, 5.0])
}

///|
test "transform normalization and winsorization are bounded" {
  let z = normalize_zscore([1.0, 2.0, 3.0])
  assert_true(absolute(mean(z)) < 1.0e-12)
  let scaled = normalize_minmax([1.0, 2.0, 3.0])
  assert_eq(scaled[0], 0.0)
  assert_eq(scaled[2], 1.0)
  assert_true(array_maximum(winsorize([1.0, 2.0, 3.0, 100.0])) < 100.0)
}
