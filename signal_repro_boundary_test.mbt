///|
test "signal scenarios are deterministic for equal seeds" {
  let scenario = SignalScenario::mean_shift(
    length=32,
    change_at=16,
    baseline=1.0,
    shift=3.0,
    noise=0.1,
    seed=11L,
  )
  assert_eq(generate_signal(scenario), generate_signal(scenario))
  assert_eq(scenario_truth(scenario), [16])
}

///|
test "signal scenario preserves requested length" {
  let scenario = SignalScenario::mean_shift(
    length=0,
    change_at=4,
    baseline=1.0,
    shift=2.0,
    noise=0.0,
    seed=1L,
  )
  assert_eq(generate_signal(scenario).length(), 1)
}

///|
test "scenario change position is clamped by generated signal" {
  let scenario = SignalScenario::mean_shift(
    length=8,
    change_at=99,
    baseline=1.0,
    shift=2.0,
    noise=0.0,
    seed=1L,
  )
  let values = generate_signal(scenario)
  assert_eq(values.length(), 8)
  assert_true(values[7] >= values[0])
}

///|
test "trend signal has a positive deterministic slope" {
  let scenario = SignalScenario::trend(
    length=20,
    change_at=10,
    baseline=0.0,
    noise=0.0,
    trend=0.5,
    seed=2L,
  )
  let values = generate_signal(scenario)
  assert_true(linear_slope(values) > 0.0)
}

///|
test "spike signal contains a localized excursion" {
  let scenario = SignalScenario::spike(
    length=24,
    spike_at=12,
    baseline=0.0,
    spike=5.0,
    noise=0.0,
    seed=3L,
  )
  let values = generate_signal(scenario)
  assert_eq(values.length(), 24)
  assert_true(array_maximum(values) >= 5.0)
}

///|
test "missing mask is reproducible and bounded" {
  let values = [1.0, 2.0, 3.0, 4.0]
  let masked = mask_every(values, 2, offset=0)
  assert_eq(masked.length(), 4)
  assert_true(!is_finite(masked[0]))
  assert_true(is_finite(masked[1]))
  assert_true(!is_finite(masked[2]))
}

///|
test "timestamp points increase by requested step" {
  let points = timestamped_signal([1.0, 2.0, 3.0], start=100L, step=10L)
  assert_eq(points[0].timestamp, 100L)
  assert_eq(points[1].timestamp, 110L)
  assert_eq(points[2].sequence, 2)
}

///|
test "reorder points reverses an arrival order deterministically" {
  let points = timestamped_signal([1.0, 2.0, 3.0, 4.0], start=0L, step=1L)
  let reordered = reorder_periodic(points, 2)
  assert_eq(reordered.length(), 4)
  assert_eq(reordered[0].timestamp, points[1].timestamp)
}

///|
test "signal checksum distinguishes values" {
  assert_true(signal_checksum([1.0, 2.0]) != signal_checksum([1.0, 3.0]))
  assert_eq(signal_checksum([]), 0.0)
}

///|
test "benchmark result summaries are human readable" {
  let result = BenchmarkResult::empty("empty")
  assert_true(result.summary().contains("samples=0"))
  assert_true(benchmark_markdown([result]).contains("detector"))
}

///|
test "benchmark suite has the three acceptance methods" {
  let results = benchmark_suite(rounds=1)
  assert_eq(results.length(), 3)
  assert_true(results[0].passes > 0)
  assert_true(results[1].samples == results[2].samples)
}

///|
test "benchmark rounds scale pass counts" {
  let one = benchmark_suite(rounds=1)
  let two = benchmark_suite(rounds=2)
  assert_eq(two[0].passes, one[0].passes * 2)
  assert_eq(two[1].passes, one[1].passes * 2)
}

///|
test "signal generator supports all named patterns" {
  let stable = generate_signal(
    SignalScenario::stable(length=5, baseline=1.0, noise=0.0, seed=1L),
  )
  let combined = generate_signal(
    SignalScenario::mean_and_variance(
      length=5,
      change_at=2,
      baseline=1.0,
      shift=1.0,
      noise=0.0,
      post_noise=0.1,
      seed=1L,
    ),
  )
  assert_eq(stable.length(), 5)
  assert_eq(combined.length(), 5)
}
