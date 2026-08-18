///|
test "deterministic signals repeat exactly" {
  let scenario = SignalScenario::mean_shift(length=64, change_at=32, seed=2026L)
  let first = generate_signal(scenario)
  let second = generate_signal(scenario)
  assert_eq(first, second)
  assert_eq(scenario_truth(scenario), [32])
  assert_eq(signal_checksum(first), signal_checksum(second))
}

///|
test "signal patterns preserve requested length" {
  assert_eq(generate_signal(SignalScenario::stable(length=0)).length(), 1)
  assert_eq(
    generate_signal(SignalScenario::variance_shift(length=17)).length(),
    17,
  )
  assert_eq(generate_signal(SignalScenario::trend(length=19)).length(), 19)
  assert_eq(generate_signal(SignalScenario::spike(length=23)).length(), 23)
}

///|
test "signal masks and interpolation repair missing values" {
  let masked = mask_every([1.0, 2.0, 3.0, 4.0, 5.0], 2, offset=0)
  assert_eq(is_finite(masked[0]), false)
  let repaired = interpolate_missing(masked)
  assert_eq(repaired, [2.0, 2.0, 3.0, 4.0, 4.0])
  assert_eq(remove_invalid(masked).length(), 2)
}

///|
test "timestamp and periodic reorder are deterministic" {
  let points = timestamped_signal([1.0, 2.0, 3.0, 4.0], start=10L, step=5L)
  assert_eq(points[2].timestamp, 20L)
  let reordered = reorder_periodic(points, 2)
  assert_eq(reordered[0].timestamp, 15L)
  assert_eq(reordered[1].timestamp, 10L)
}

///|
test "benchmark suite produces real work and known sample count" {
  let results = benchmark_suite(rounds=2)
  assert_eq(results.length(), 3)
  for result in results {
    assert_eq(result.samples, 512)
    assert_eq(result.passes, 1024)
    assert_true(result.checksum != 0.0)
    assert_eq(result.truth_count, 1)
  }
  assert_true(benchmark_markdown(results).length() > 100)
}

///|
test "benchmark single detector reports first index" {
  let scenario = SignalScenario::mean_shift(
    length=128,
    change_at=64,
    shift=4.0,
    noise=0.0,
  )
  let result = benchmark_cusum(scenario)
  assert_eq(result.samples, 128)
  assert_true(result.detections > 0)
  assert_true(result.first_detection >= 0)
}
