///|
test "event history is bounded and counts critical events" {
  let history = EventHistory::new(capacity=2)
  let point = ChangePoint::from_result(
    SignalPoint::new(1L, 3.0),
    DetectionResult::new(true, 2.0, 1.0, Unknown, 1),
    "cpu",
    0.0,
  )
  history.push(AlertEvent::new("cpu", point))
  history.push(AlertEvent::new("cpu", point, suppressed=true))
  history.push(AlertEvent::new("cpu", point))
  assert_eq(history.length(), 2)
  assert_eq(history.total(), 3)
  assert_eq(history.unsuppressed_count(), 1)
  assert_true(history.latest() is Some(_))
}

///|
test "event deduplication uses metric and timestamp" {
  let result = DetectionResult::new(true, 1.0, 1.0, Unknown, 1)
  let first = ChangePoint::from_result(
    SignalPoint::new(10L, 1.0),
    result,
    "cpu",
    0.0,
  )
  let second = ChangePoint::from_result(
    SignalPoint::new(11L, 1.0),
    result,
    "cpu",
    0.0,
  )
  let third = ChangePoint::from_result(
    SignalPoint::new(11L, 1.0),
    result,
    "memory",
    0.0,
  )
  let events = deduplicate_events(
    [
      AlertEvent::new("cpu", first),
      AlertEvent::new("cpu", second),
      AlertEvent::new("memory", third),
    ],
    2L,
  )
  assert_eq(events.length(), 2)
  assert_true(event_rate(events, 0L, 10L) > 0.0)
}

///|
test "resampling interpolates timestamp gaps" {
  let points = [SignalPoint::new(0L, 0.0), SignalPoint::new(10L, 10.0)]
  let resampled = resample_linear(points, 5L)
  assert_eq(resampled.length(), 3)
  assert_eq(resampled[1].value, 5.0)
  assert_eq(resampled[2].timestamp, 10L)
}

///|
test "alignment and lag preserve matching samples" {
  let left = [
    SignalPoint::new(0L, 1.0),
    SignalPoint::new(2L, 3.0),
    SignalPoint::new(4L, 5.0),
  ]
  let right = [
    SignalPoint::new(1L, 2.0),
    SignalPoint::new(2L, 4.0),
    SignalPoint::new(4L, 6.0),
  ]
  let (a, b) = align_by_timestamp(left, right)
  assert_eq(a, [3.0, 5.0])
  assert_eq(b, [4.0, 6.0])
  assert_eq(lag_points(left, 10L)[0].timestamp, 10L)
}

///|
test "rolling quantile follows rolling window" {
  let values = rolling_quantile([1.0, 2.0, 9.0], 2, 0.5)
  assert_eq(values, [1.0, 1.5, 5.5])
}
