///|
/// Linearly interpolates invalid observations while retaining valid endpoints.
pub fn interpolate_missing(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  for value in values {
    result.push(value)
  }
  let mut previous = -1
  let mut first_valid = -1
  for i in 0..<result.length() {
    if is_finite(result[i]) {
      if first_valid < 0 {
        first_valid = i
      }
      if previous >= 0 && i - previous > 1 {
        let left = result[previous]
        let right = result[i]
        for j in (previous + 1)..<i {
          result[j] = left +
            (right - left) *
            (j - previous).to_double() /
            (i - previous).to_double()
        }
      }
      previous = i
    }
  }
  if first_valid >= 0 {
    for i in 0..<first_valid {
      if !is_finite(result[i]) {
        result[i] = result[first_valid]
      }
    }
  }
  if previous >= 0 {
    for i in (previous + 1)..<result.length() {
      if !is_finite(result[i]) {
        result[i] = result[previous]
      }
    }
  }
  result
}

///|
pub fn clip(
  values : Array[Double],
  lower : Double,
  upper : Double,
) -> Array[Double] {
  let low = if lower < upper { lower } else { upper }
  let high = if upper > lower { upper } else { lower }
  let result : Array[Double] = []
  for value in values {
    result.push(
      if value < low {
        low
      } else if value > high {
        high
      } else {
        value
      },
    )
  }
  result
}

///|
pub fn winsorize(
  values : Array[Double],
  lower_probability? : Double = 0.05,
  upper_probability? : Double = 0.95,
) -> Array[Double] {
  clip(
    values,
    quantile(values, lower_probability),
    quantile(values, upper_probability),
  )
}

///|
pub fn normalize_zscore(values : Array[Double]) -> Array[Double] {
  let center = mean(values)
  let scale = standard_deviation(values)
  let safe_scale = if scale < 1.0e-12 { 1.0 } else { scale }
  let result : Array[Double] = []
  for value in values {
    result.push((value - center) / safe_scale)
  }
  result
}

///|
pub fn normalize_minmax(values : Array[Double]) -> Array[Double] {
  let low = array_minimum(values)
  let high = array_maximum(values)
  let range = high - low
  let result : Array[Double] = []
  for value in values {
    result.push(if range <= 1.0e-12 { 0.0 } else { (value - low) / range })
  }
  result
}

///|
pub fn difference(values : Array[Double], lag? : Int = 1) -> Array[Double] {
  let result : Array[Double] = []
  let safe_lag = if lag < 1 { 1 } else { lag }
  if values.length() <= safe_lag {
    return result
  }
  for i in safe_lag..<values.length() {
    result.push(values[i] - values[i - safe_lag])
  }
  result
}

///|
pub fn cumulative_sum(
  values : Array[Double],
  initial? : Double = 0.0,
) -> Array[Double] {
  let result : Array[Double] = []
  let mut total = initial
  for value in values {
    total += value
    result.push(total)
  }
  result
}

///|
pub fn moving_average(
  values : Array[Double],
  window_size : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  let window = DoubleWindow::new(window_size)
  for value in values {
    ignore(window.push(value))
    result.push(window.mean())
  }
  result
}

///|
pub fn moving_median(
  values : Array[Double],
  window_size : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  let window = DoubleWindow::new(window_size)
  for value in values {
    ignore(window.push(value))
    result.push(window.median())
  }
  result
}

///|
pub fn downsample_mean(values : Array[Double], factor : Int) -> Array[Double] {
  let result : Array[Double] = []
  let size = if factor < 1 { 1 } else { factor }
  let mut window : Array[Double] = []
  for value in values {
    window.push(value)
    if window.length() == size {
      result.push(mean(window))
      window = []
    }
  }
  if window.length() > 0 {
    result.push(mean(window))
  }
  result
}
