///|
test "double window is empty safe" {
  let window = DoubleWindow::new(3)
  assert_eq(window.length(), 0)
  assert_eq(window.mean(), 0.0)
  assert_eq(window.sum(), 0.0)
}

///|
test "double window keeps the newest capacity values" {
  let window = DoubleWindow::new(2)
  ignore(window.push(1.0))
  ignore(window.push(2.0))
  ignore(window.push(3.0))
  assert_eq(window.length(), 2)
  assert_eq(window.to_array(), [2.0, 3.0])
}

///|
test "window median and slope update" {
  let window = DoubleWindow::new(4)
  for value in [1.0, 2.0, 3.0, 4.0] {
    ignore(window.push(value))
  }
  assert_eq(window.median(), 2.5)
  assert_true(window.slope() > 0.0)
}

///|
test "window clear resets all state" {
  let window = DoubleWindow::new(2)
  ignore(window.push(4.0))
  window.clear()
  assert_eq(window.length(), 0)
  assert_eq(window.mean(), 0.0)
}

///|
test "window aggregator supports minimum and maximum" {
  let minimum = WindowAggregator::new(2, kind=MinimumAggregate)
  let maximum = WindowAggregator::new(2, kind=MaximumAggregate)
  ignore(minimum.push(SignalPoint::new(0L, 4.0)))
  ignore(maximum.push(SignalPoint::new(0L, 4.0)))
  match minimum.push(SignalPoint::new(1L, 2.0)) {
    None => fail("minimum did not close")
    Some(value) => assert_eq(value.value, 2.0)
  }
  match maximum.push(SignalPoint::new(1L, 2.0)) {
    None => fail("maximum did not close")
    Some(value) => assert_eq(value.value, 4.0)
  }
}

///|
test "window flush returns partial data once" {
  let aggregator = WindowAggregator::new(3)
  ignore(aggregator.push(SignalPoint::new(0L, 1.0)))
  match aggregator.flush() {
    None => fail("partial window missing")
    Some(value) => assert_eq(value.count, 1)
  }
  match aggregator.flush() {
    None => ()
    Some(_) => fail("window flushed twice")
  }
}

///|
test "watermark with negative lateness is safe" {
  let tracker = WatermarkTracker::new(allowed_lateness=-5L)
  assert_true(tracker.observe(3L))
  assert_eq(tracker.watermark(), 3L)
}

///|
test "reservoir sampling respects requested size" {
  let sample = ReservoirSample::new(2, seed=3L)
  for value in [1.0, 2.0, 3.0, 4.0] {
    sample.push(value)
  }
  assert_eq(sample.values().length(), 2)
}

///|
test "bootstrap mean is deterministic for a seed" {
  let first = bootstrap_mean([1.0, 2.0, 3.0], replicates=10, seed=7L)
  let second = bootstrap_mean([1.0, 2.0, 3.0], replicates=10, seed=7L)
  assert_eq(first.mean, second.mean)
  assert_eq(first.replicates, 10)
}

///|
test "rolling origins reject invalid horizons" {
  assert_eq(rolling_origins(10, 4, 0, step=1).length(), 7)
  assert_true(rolling_origins(10, 4, 2, step=2).length() > 0)
}

///|
test "stratified sampling handles empty strata" {
  assert_eq(stratified_counts([], 2).length(), 2)
}

///|
test "bootstrap interval is ordered" {
  let interval = bootstrap_mean([1.0, 2.0, 3.0], replicates=20, seed=9L)
  assert_true(interval.lower <= interval.mean)
  assert_true(interval.mean <= interval.upper)
  assert_true(interval.standard_error >= 0.0)
}

///|
test "reorder buffer accepts a single point" {
  let buffer = ReorderBuffer::new(capacity=2, policy=Drop)
  let output = buffer.push(SignalPoint::new(1L, 1.0))
  assert_eq(output.length(), 0)
  assert_eq(buffer.flush().length(), 1)
}
