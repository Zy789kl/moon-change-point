///|
test "quality report counts finite and out of range values" {
  let report = validate_values(
    [1.0, 2.0, 99.0, 0.0 / 0.0],
    lower=Some(0.0),
    upper=Some(10.0),
  )
  assert_eq(report.count, 4)
  assert_eq(report.valid, 2)
  assert_eq(report.non_finite, 1)
  assert_eq(report.out_of_range, 1)
  assert_eq(report.is_healthy(), false)
  assert_true(report.valid_ratio() > 0.4)
}

///|
test "quality points detect ordering and gaps" {
  let points = [
    SignalPoint::new(0L, 1.0),
    SignalPoint::new(5L, 2.0),
    SignalPoint::new(3L, 0.0 / 0.0),
  ]
  let report = validate_points(points, maximum_gap=Some(2L))
  assert_eq(report.non_monotonic, 1)
  assert_eq(report.excessive_gaps, 1)
  assert_eq(report.non_finite, 1)
  assert_eq(quality_score(report), 0.0)
}

///|
test "quality transformations preserve length" {
  let values = [0.0 / 0.0, 1.0, 2.0, 0.0 / 0.0]
  assert_eq(replace_invalid(values, replacement=9.0), [9.0, 1.0, 2.0, 9.0])
  assert_eq(remove_invalid(values), [1.0, 2.0])
  assert_eq(clip([0.0, 5.0, 10.0], 2.0, 8.0), [2.0, 5.0, 8.0])
}

///|
test "quality gate applies ratio and monotonic rules" {
  let gate = DataQualityGate::new(minimum_ratio=0.8)
  assert_eq(gate.accept(validate_values([1.0, 2.0, 3.0])), true)
  assert_eq(gate.accept(validate_values([1.0, 0.0 / 0.0, 3.0])), false)
}

///|
test "quality contiguous ranges split large gaps" {
  let ranges = contiguous_ranges(
    [
      SignalPoint::new(0L, 1.0),
      SignalPoint::new(1L, 1.0),
      SignalPoint::new(10L, 1.0),
    ],
    2L,
  )
  assert_eq(ranges.length(), 2)
  assert_eq(ranges[0].start, 0)
  assert_eq(ranges[0].end, 2)
  assert_eq(ranges[1].start, 2)
}

///|
test "reservoir sample is bounded and reproducible" {
  let first = ReservoirSample::new(3, seed=123L)
  let second = ReservoirSample::new(3, seed=123L)
  for i in 0..<100 {
    first.push(i.to_double())
    second.push(i.to_double())
  }
  assert_eq(first.seen(), 100)
  assert_eq(first.values(), second.values())
  assert_eq(first.values().length(), 3)
}

///|
test "bootstrap estimate has ordered interval" {
  let result = bootstrap_mean([1.0, 2.0, 3.0, 4.0], replicates=25, seed=7L)
  assert_eq(result.replicates, 25)
  assert_true(result.lower <= result.mean)
  assert_true(result.mean <= result.upper)
  assert_true(result.standard_error >= 0.0)
}

///|
test "sampling plans handle tiny data" {
  let (train, holdout) = split_train_test([1.0, 2.0, 3.0], train_fraction=0.5)
  assert_eq(train.length(), 1)
  assert_eq(holdout.length(), 2)
  assert_eq(rolling_origins(10, 4, 2, step=2).length(), 3)
  assert_eq(stratified_counts([0.0, 0.5, 1.0], 2), [1, 2])
}
