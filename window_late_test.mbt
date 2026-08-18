///|
test "window keeps newest values after overflow" {
  let window = DoubleWindow::new(3)
  assert_eq(window.is_empty(), true)
  ignore(window.push(1.0))
  ignore(window.push(2.0))
  ignore(window.push(3.0))
  assert_eq(window.is_full(), true)
  match window.push(4.0) {
    None => fail("expected eviction")
    Some(value) => assert_eq(value, 1.0)
  }
  assert_eq(window.to_array(), [2.0, 3.0, 4.0])
  assert_eq(window.first(), Some(2.0))
  assert_eq(window.last(), Some(4.0))
}

///|
test "window invalid indexes return none" {
  let window = DoubleWindow::new(2)
  assert_eq(window.get(-1), None)
  assert_eq(window.get(0), None)
  ignore(window.push(9.0))
  assert_eq(window.get(0), Some(9.0))
  assert_eq(window.get(2), None)
}

///|
test "window statistics follow ring order" {
  let window = DoubleWindow::new(4)
  for value in [1.0, 2.0, 3.0, 4.0] {
    ignore(window.push(value))
  }
  assert_eq(window.sum(), 10.0)
  assert_eq(window.mean(), 2.5)
  assert_eq(window.median(), 2.5)
  assert_eq(window.quantile(0.75), 3.25)
  assert_eq(window.slope(), 1.0)
  window.clear()
  assert_eq(window.length(), 0)
}

///|
test "reorder buffer sorts late points and flushes" {
  let buffer = ReorderBuffer::new(capacity=2, policy=KeepForCorrection)
  let first = buffer.push(SignalPoint::new(2L, 2.0))
  assert_eq(first.length(), 0)
  let second = buffer.push(SignalPoint::new(1L, 1.0))
  assert_eq(second.length(), 0)
  let third = buffer.push(SignalPoint::new(3L, 3.0))
  assert_eq(third.length(), 1)
  assert_eq(third[0].point.timestamp, 1L)
  let rest = buffer.flush()
  assert_eq(rest.length(), 2)
  assert_eq(rest[0].point.timestamp, 2L)
  assert_eq(rest[1].point.timestamp, 3L)
  assert_eq(buffer.late_count(), 0)
  ignore(buffer.push(SignalPoint::new(0L, 0.0)))
  assert_eq(buffer.late_count(), 1)
}

///|
test "reorder drop policy records dropped points" {
  let buffer = ReorderBuffer::new(capacity=1, policy=Drop)
  ignore(buffer.push(SignalPoint::new(10L, 1.0)))
  ignore(buffer.flush())
  let output = buffer.push(SignalPoint::new(1L, 1.0))
  assert_eq(output.length(), 0)
  assert_eq(buffer.dropped_count(), 1)
}

///|
test "reorder replace policy removes duplicate timestamps" {
  let buffer = ReorderBuffer::new(capacity=4, policy=ReplaceSameTimestamp)
  ignore(buffer.push(SignalPoint::new(3L, 1.0)))
  ignore(buffer.push(SignalPoint::new(3L, 9.0)))
  let pending = buffer.peek()
  assert_eq(pending.length(), 1)
  assert_eq(pending[0].point.value, 9.0)
}

///|
test "window handles normalized capacity" {
  let window = DoubleWindow::new(0)
  assert_eq(window.capacity(), 1)
  ignore(window.push(1.0))
  ignore(window.push(2.0))
  assert_eq(window.to_array(), [2.0])
}
