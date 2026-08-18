///|
/// Time-window planning utilities for batch and streaming consumers.
pub struct TimeWindow {
  start : Int64
  end : Int64
  ordinal : Int
}

///|
pub fn TimeWindow::new(start : Int64, end : Int64, ordinal : Int) -> TimeWindow {
  { start, end, ordinal }
}

///|
pub fn TimeWindow::duration(self : TimeWindow) -> Int64 {
  self.end - self.start
}

///|
pub fn TimeWindow::contains(self : TimeWindow, timestamp : Int64) -> Bool {
  timestamp >= self.start && timestamp < self.end
}

///|
pub fn TimeWindow::is_empty(self : TimeWindow) -> Bool {
  self.end <= self.start
}

///|
pub fn make_time_windows(
  start : Int64,
  end : Int64,
  width : Int64,
  step? : Int64 = 0L,
) -> Array[TimeWindow] {
  let result : Array[TimeWindow] = []
  if width <= 0L || end <= start {
    return result
  }
  let stride = if step <= 0L { width } else { step }
  let mut cursor = start
  let mut ordinal = 0
  while cursor < end {
    let boundary = if cursor + width > end { end } else { cursor + width }
    result.push(TimeWindow::new(cursor, boundary, ordinal))
    cursor += stride
    ordinal += 1
  }
  result
}

///|
pub fn locate_time_window(
  windows : Array[TimeWindow],
  timestamp : Int64,
) -> Int {
  for window in windows {
    if window.contains(timestamp) {
      return window.ordinal
    }
  }
  -1
}

///|
pub fn bucket_timestamp(
  timestamp : Int64,
  origin : Int64,
  width : Int64,
) -> Int64 {
  if width <= 0L {
    origin
  } else {
    origin + (timestamp - origin) / width * width
  }
}

///|
pub fn window_counts(
  points : Array[SignalPoint],
  windows : Array[TimeWindow],
) -> Array[Int] {
  let result = Array::make(windows.length(), 0)
  for point in points {
    let ordinal = locate_time_window(windows, point.timestamp)
    if ordinal >= 0 && ordinal < result.length() {
      result[ordinal] += 1
    }
  }
  result
}

///|
pub fn window_means(
  points : Array[SignalPoint],
  windows : Array[TimeWindow],
) -> Array[Double] {
  let values : Array[Array[Double]] = []
  for _ in windows {
    values.push([])
  }
  for point in points {
    let ordinal = locate_time_window(windows, point.timestamp)
    if ordinal >= 0 && ordinal < values.length() {
      values[ordinal].push(point.value)
    }
  }
  let result : Array[Double] = []
  for bucket in values {
    result.push(mean(bucket))
  }
  result
}

///|
pub fn window_summaries(
  points : Array[SignalPoint],
  windows : Array[TimeWindow],
) -> Array[StatsSummary] {
  let values : Array[Array[Double]] = []
  for _ in windows {
    values.push([])
  }
  for point in points {
    let ordinal = locate_time_window(windows, point.timestamp)
    if ordinal >= 0 && ordinal < values.length() {
      values[ordinal].push(point.value)
    }
  }
  let result : Array[StatsSummary] = []
  for bucket in values {
    let accumulator = OnlineMoments::new()
    for value in bucket {
      accumulator.push(value)
    }
    result.push(accumulator.summary(median=median(bucket)))
  }
  result
}

///|
pub fn time_window_csv(
  windows : Array[TimeWindow],
  counts : Array[Int],
) -> String {
  let mut output = "ordinal,start,end,count\n"
  let length = if windows.length() < counts.length() {
    windows.length()
  } else {
    counts.length()
  }
  for i in 0..<length {
    output = output +
      i.to_string() +
      "," +
      windows[i].start.to_string() +
      "," +
      windows[i].end.to_string() +
      "," +
      counts[i].to_string() +
      "\n"
  }
  output
}
