///|
/// Robust preprocessing helpers for production telemetry.
pub fn winsorize_robust(
  values : Array[Double],
  lower_probability : Double,
  upper_probability : Double,
) -> Array[Double] {
  if values.length() == 0 {
    return []
  }
  let low = quantile(values, lower_probability)
  let high = quantile(values, upper_probability)
  let result : Array[Double] = []
  for value in values {
    if value < low {
      result.push(low)
    } else if value > high {
      result.push(high)
    } else {
      result.push(value)
    }
  }
  result
}

///|
pub fn robust_z_score(
  value : Double,
  center : Double,
  scale : Double,
) -> Double {
  if scale <= 0.0 {
    0.0
  } else {
    absolute(value - center) / scale
  }
}

///|
pub fn robust_z_scores(values : Array[Double]) -> Array[Double] {
  let center = median(values)
  let scale = robust_scale(values)
  let result : Array[Double] = []
  for value in values {
    result.push(robust_z_score(value, center, scale))
  }
  result
}

///|
pub fn outlier_mask(
  values : Array[Double],
  threshold? : Double = 3.5,
) -> Array[Bool] {
  let safe = if threshold < 0.0 { 0.0 } else { threshold }
  let scores = robust_z_scores(values)
  let result : Array[Bool] = []
  for score in scores {
    result.push(score > safe)
  }
  result
}

///|
pub fn hampel_filter(
  values : Array[Double],
  window_size? : Int = 7,
  threshold? : Double = 3.0,
) -> Array[Double] {
  let safe_window = if window_size < 1 { 1 } else { window_size }
  let result : Array[Double] = []
  for i in 0..<values.length() {
    let start = if i < safe_window { 0 } else { i - safe_window + 1 }
    let window_values : Array[Double] = []
    for j in start..<(i + 1) {
      window_values.push(values[j])
    }
    let center = median(window_values)
    let scale = median_absolute_deviation(window_values) * 1.4826
    if (scale == 0.0 && values[i] != center) ||
      (scale > 0.0 && absolute(values[i] - center) > threshold * scale) {
      result.push(center)
    } else {
      result.push(values[i])
    }
  }
  result
}

///|
pub fn clip_values(
  values : Array[Double],
  minimum : Double,
  maximum : Double,
) -> Array[Double] {
  let low = if minimum <= maximum { minimum } else { maximum }
  let high = if minimum <= maximum { maximum } else { minimum }
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
pub fn normalize_range(
  values : Array[Double],
  minimum? : Double = 0.0,
  maximum? : Double = 1.0,
) -> Array[Double] {
  let source_low = array_minimum(values)
  let source_high = array_maximum(values)
  let target_low = minimum
  let target_high = maximum
  let result : Array[Double] = []
  for value in values {
    if source_high == source_low {
      result.push((target_low + target_high) / 2.0)
    } else {
      result.push(
        target_low +
        (value - source_low) *
        (target_high - target_low) /
        (source_high - source_low),
      )
    }
  }
  result
}

///|
pub fn first_difference(values : Array[Double]) -> Array[Double] {
  if values.length() < 2 {
    return []
  }
  let result : Array[Double] = []
  for i in 1..<values.length() {
    result.push(values[i] - values[i - 1])
  }
  result
}

///|
pub fn second_difference(values : Array[Double]) -> Array[Double] {
  first_difference(first_difference(values))
}

///|
pub fn cumulative_total(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  let mut total = 0.0
  for value in values {
    total += value
    result.push(total)
  }
  result
}

///|
pub fn lag_values(values : Array[Double], lag : Int) -> Array[Double] {
  let result : Array[Double] = []
  if lag <= 0 {
    return values
  }
  for i in 0..<values.length() {
    result.push(if i < lag { 0.0 } else { values[i - lag] })
  }
  result
}

///|
pub fn rolling_mean(values : Array[Double], window_size : Int) -> Array[Double] {
  let result : Array[Double] = []
  let safe = if window_size < 1 { 1 } else { window_size }
  for i in 0..<values.length() {
    let start = if i + 1 < safe { 0 } else { i + 1 - safe }
    let window_values : Array[Double] = []
    for j in start..<(i + 1) {
      window_values.push(values[j])
    }
    result.push(mean(window_values))
  }
  result
}

///|
pub fn rolling_standard_deviation(
  values : Array[Double],
  window_size : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  let safe = if window_size < 1 { 1 } else { window_size }
  for i in 0..<values.length() {
    let start = if i + 1 < safe { 0 } else { i + 1 - safe }
    let window_values : Array[Double] = []
    for j in start..<(i + 1) {
      window_values.push(values[j])
    }
    result.push(standard_deviation(window_values))
  }
  result
}

///|
pub fn rolling_slope(
  values : Array[Double],
  window_size : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  let safe = if window_size < 2 { 2 } else { window_size }
  for i in 0..<values.length() {
    let start = if i + 1 < safe { 0 } else { i + 1 - safe }
    let window_values : Array[Double] = []
    for j in start..<(i + 1) {
      window_values.push(values[j])
    }
    result.push(linear_slope(window_values))
  }
  result
}

///|
pub fn exponential_smooth(
  values : Array[Double],
  alpha? : Double = 0.2,
) -> Array[Double] {
  let result : Array[Double] = []
  if values.length() == 0 {
    return result
  }
  let rate = clamp_probability(alpha)
  let mut level = values[0]
  result.push(level)
  for i in 1..<values.length() {
    level = rate * values[i] + (1.0 - rate) * level
    result.push(level)
  }
  result
}

///|
pub fn forward_fill(
  values : Array[Double],
  fallback? : Double = 0.0,
) -> Array[Double] {
  let result : Array[Double] = []
  let mut last = fallback
  for value in values {
    if is_finite(value) {
      last = value
    }
    result.push(last)
  }
  result
}

///|
pub fn robust_scale(values : Array[Double]) -> Double {
  let scale = median_absolute_deviation(values) * 1.4826
  if scale == 0.0 {
    standard_deviation(values)
  } else {
    scale
  }
}
