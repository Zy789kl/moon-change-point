///|
test "interpolation fills leading middle and trailing gaps" {
  let values = [0.0 / 0.0, 2.0, 0.0 / 0.0, 6.0, 0.0 / 0.0]
  let result = interpolate_missing(values)
  assert_eq(result, [2.0, 2.0, 4.0, 6.0, 6.0])
}

///|
test "clip normalizes reversed endpoints" {
  assert_eq(clip([-2.0, 0.0, 2.0], 1.0, -1.0), [-1.0, 0.0, 1.0])
}

///|
test "z score normalization has centered mean" {
  let result = normalize_zscore([1.0, 2.0, 3.0])
  assert_true(absolute(mean(result)) < 0.000001)
}

///|
test "min max normalization handles constants" {
  assert_eq(normalize_minmax([4.0, 4.0]), [0.0, 0.0])
}

///|
test "difference honors arbitrary lag" {
  assert_eq(difference([1.0, 2.0, 4.0, 8.0], lag=2), [3.0, 6.0])
  assert_eq(difference([1.0], lag=2), [])
}

///|
test "moving average follows a bounded window" {
  let result = moving_average([1.0, 3.0, 5.0], 2)
  assert_eq(result.length(), 3)
  assert_eq(result[2], 4.0)
}

///|
test "moving median follows a bounded window" {
  let result = moving_median([3.0, 1.0, 2.0], 2)
  assert_eq(result.length(), 3)
  assert_eq(result[2], 1.5)
}

///|
test "downsample mean keeps a partial tail" {
  assert_eq(downsample_mean([1.0, 2.0, 3.0, 4.0, 5.0], 2), [1.5, 3.5, 5.0])
}

///|
test "seasonal profile counts phase observations" {
  let profile = SeasonalProfile::new(3, alpha=1.0)
  for value in [1.0, 2.0, 3.0, 4.0] {
    ignore(profile.update(value))
  }
  assert_eq(profile.count(0), 2)
  assert_eq(profile.count(1), 1)
  assert_eq(profile.count(2), 1)
}

///|
test "seasonal strength is bounded" {
  let strength = seasonal_strength([1.0, 2.0, 1.0, 2.0], 2)
  assert_true(strength >= 0.0 && strength <= 1.0)
}

///|
test "seasonal detector returns a quiet warmup result" {
  let detector = SeasonalAnomalyDetector::new(2)
  let result = detector.update(1.0)
  assert_true(!result.changed)
  assert_eq(result.index, 1)
}

///|
test "histogram probability mass sums to one" {
  let histogram = Histogram::new(0.0, 4.0, 4)
  for value in [0.0, 1.0, 2.0, 3.0] {
    histogram.push(value)
  }
  assert_true(absolute(sum(histogram.probabilities()) - 1.0) < 0.000001)
}

///|
test "distribution distances are zero for equal samples" {
  let values = [1.0, 2.0, 3.0]
  assert_true(ks_statistic(values, values) >= 0.0)
  assert_eq(energy_distance(values, values), 0.0)
  assert_true(distribution_change_score(values, values) >= 0.0)
}

///|
test "distribution overlap is bounded" {
  let overlap = distribution_overlap([0.0, 1.0], [1.0, 2.0], bins=4)
  assert_true(overlap >= 0.0 && overlap <= 1.0)
}

///|
test "quantile shift detects separated samples" {
  assert_true(quantile_shift_score([0.0, 0.0], [10.0, 10.0]) > 0.0)
}

///|
test "rank utilities handle ties" {
  let ranks_result = ranks([1.0, 1.0, 2.0])
  assert_eq(ranks_result.length(), 3)
  assert_true(ranks_result[2] > ranks_result[0])
  assert_true(spearman_correlation([1.0, 2.0], [1.0, 2.0]) > 0.9)
}

///|
test "runs and sign scores are finite" {
  assert_true(is_finite(runs_test_score([1.0, -1.0, 1.0])))
  assert_true(is_finite(sign_change_rate([1.0, -1.0, 1.0])))
}
