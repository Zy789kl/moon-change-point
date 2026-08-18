///|
pub fn resample_linear(
  points : Array[SignalPoint],
  step : Int64,
) -> Array[SignalPoint] {
  let result : Array[SignalPoint] = []
  if points.length() == 0 || step <= 0L {
    return result
  }
  let mut timestamp = points[0].timestamp
  let last = points[points.length() - 1].timestamp
  let mut cursor = 0
  while timestamp <= last {
    while cursor + 1 < points.length() &&
          points[cursor + 1].timestamp < timestamp {
      cursor += 1
    }
    if cursor + 1 >= points.length() {
      result.push(SignalPoint::new(timestamp, points[cursor].value))
      timestamp += step
      continue
    }
    let left = points[cursor]
    let right = points[cursor + 1]
    let value = if right.timestamp == left.timestamp {
      right.value
    } else {
      left.value +
      (right.value - left.value) *
      (timestamp - left.timestamp).to_double() /
      (right.timestamp - left.timestamp).to_double()
    }
    result.push(SignalPoint::new(timestamp, value))
    timestamp += step
  }
  result
}

///|
pub fn align_by_timestamp(
  left : Array[SignalPoint],
  right : Array[SignalPoint],
) -> (Array[Double], Array[Double]) {
  let a : Array[Double] = []
  let b : Array[Double] = []
  let mut i = 0
  let mut j = 0
  while i < left.length() && j < right.length() {
    if left[i].timestamp == right[j].timestamp {
      a.push(left[i].value)
      b.push(right[j].value)
      i += 1
      j += 1
    } else if left[i].timestamp < right[j].timestamp {
      i += 1
    } else {
      j += 1
    }
  }
  (a, b)
}

///|
pub fn lag_points(
  points : Array[SignalPoint],
  lag : Int64,
) -> Array[SignalPoint] {
  let result : Array[SignalPoint] = []
  for point in points {
    result.push(
      SignalPoint::new(
        point.timestamp + lag,
        point.value,
        sequence=point.sequence,
      ),
    )
  }
  result
}

///|
pub fn rolling_quantile(
  values : Array[Double],
  window_size : Int,
  probability : Double,
) -> Array[Double] {
  let result : Array[Double] = []
  let window = DoubleWindow::new(window_size)
  for value in values {
    ignore(window.push(value))
    result.push(window.quantile(probability))
  }
  result
}

///|
pub fn interpolate_points(
  points : Array[SignalPoint],
  step : Int64,
) -> Array[SignalPoint] {
  resample_linear(points, step)
}
