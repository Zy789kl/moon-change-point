///|
test "time windows are half open and ordered" {
  let windows = make_time_windows(0L, 10L, 5L)
  assert_eq(windows.length(), 2)
  assert_true(windows[0].contains(0L))
  assert_true(!windows[0].contains(5L))
  assert_eq(windows[1].ordinal, 1)
}

///|
test "time window builder rejects invalid ranges" {
  assert_eq(make_time_windows(0L, 10L, 0L).length(), 0)
  assert_eq(make_time_windows(10L, 0L, 2L).length(), 0)
  assert_eq(make_time_windows(0L, 1L, 5L)[0].duration(), 1L)
}

///|
test "time window locator returns a missing sentinel" {
  let windows = make_time_windows(10L, 20L, 5L)
  assert_eq(locate_time_window(windows, 12L), 0)
  assert_eq(locate_time_window(windows, 20L), -1)
}

///|
test "bucket timestamp floors to the origin" {
  assert_eq(bucket_timestamp(13L, 0L, 5L), 10L)
  assert_eq(bucket_timestamp(-1L, 0L, 5L), 0L)
  assert_eq(bucket_timestamp(13L, 0L, 0L), 0L)
}

///|
test "window counts and means align by ordinal" {
  let windows = make_time_windows(0L, 10L, 5L)
  let points = [
    SignalPoint::new(1L, 2.0),
    SignalPoint::new(6L, 4.0),
    SignalPoint::new(8L, 6.0),
  ]
  assert_eq(window_counts(points, windows), [1, 2])
  assert_eq(window_means(points, windows), [2.0, 5.0])
}

///|
test "window summaries are empty safe" {
  let windows = make_time_windows(0L, 5L, 5L)
  let summaries = window_summaries([], windows)
  assert_eq(summaries.length(), 1)
  assert_eq(summaries[0].count, 0)
}

///|
test "window CSV truncates to common length" {
  let windows = make_time_windows(0L, 10L, 5L)
  let csv = time_window_csv(windows, [2])
  assert_true(csv.contains("ordinal,start,end,count"))
  assert_true(csv.contains("0,0,5,2"))
}

///|
test "time window duration reports the exact interval" {
  let window = TimeWindow::new(4L, 9L, 3)
  assert_eq(window.duration(), 5L)
  assert_true(!window.is_empty())
}

///|
test "time window step supports overlapping windows" {
  let windows = make_time_windows(0L, 10L, 4L, step=2L)
  assert_true(windows.length() >= 4)
  assert_eq(windows[1].start, 2L)
}
