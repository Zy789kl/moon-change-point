///|
/// Numerically stable online moments using Welford's recurrence.
pub struct OnlineMoments {
  mut count : Int
  mut mean : Double
  mut m2 : Double
  mut minimum : Double
  mut maximum : Double
}

///|
/// Creates an empty accumulator.
pub fn OnlineMoments::new() -> OnlineMoments {
  { count: 0, mean: 0.0, m2: 0.0, minimum: 0.0, maximum: 0.0 }
}

///|
/// Creates an accumulator with a prior mean and effective sample size.
pub fn OnlineMoments::with_prior(
  mean : Double,
  variance : Double,
  weight : Int,
) -> OnlineMoments {
  let safe_weight = if weight < 0 { 0 } else { weight }
  {
    count: safe_weight,
    mean,
    m2: variance * safe_weight.to_double(),
    minimum: mean,
    maximum: mean,
  }
}

///|
/// Adds one observation.
pub fn OnlineMoments::push(self : OnlineMoments, value : Double) -> Unit {
  if !is_finite(value) {
    return
  }
  self.count += 1
  if self.count == 1 {
    self.mean = value
    self.minimum = value
    self.maximum = value
  } else {
    let delta = value - self.mean
    self.mean += delta / self.count.to_double()
    let delta2 = value - self.mean
    self.m2 += delta * delta2
    if value < self.minimum {
      self.minimum = value
    }
    if value > self.maximum {
      self.maximum = value
    }
  }
}

///|
pub fn OnlineMoments::count(self : OnlineMoments) -> Int {
  self.count
}

///|
pub fn OnlineMoments::mean(self : OnlineMoments) -> Double {
  self.mean
}

///|
pub fn OnlineMoments::variance(self : OnlineMoments) -> Double {
  if self.count < 2 {
    0.0
  } else {
    self.m2 / (self.count - 1).to_double()
  }
}

///|
pub fn OnlineMoments::population_variance(self : OnlineMoments) -> Double {
  if self.count == 0 {
    0.0
  } else {
    self.m2 / self.count.to_double()
  }
}

///|
pub fn OnlineMoments::standard_deviation(self : OnlineMoments) -> Double {
  self.population_variance().sqrt()
}

///|
pub fn OnlineMoments::minimum(self : OnlineMoments) -> Double {
  self.minimum
}

///|
pub fn OnlineMoments::maximum(self : OnlineMoments) -> Double {
  self.maximum
}

///|
pub fn OnlineMoments::merge(
  self : OnlineMoments,
  other : OnlineMoments,
) -> Unit {
  if other.count == 0 {
    return
  }
  if self.count == 0 {
    self.count = other.count
    self.mean = other.mean
    self.m2 = other.m2
    self.minimum = other.minimum
    self.maximum = other.maximum
    return
  }
  let total = self.count + other.count
  let delta = other.mean - self.mean
  self.m2 += other.m2 +
    delta *
    delta *
    self.count.to_double() *
    other.count.to_double() /
    total.to_double()
  self.mean = (
      self.mean * self.count.to_double() + other.mean * other.count.to_double()
    ) /
    total.to_double()
  self.count = total
  if other.minimum < self.minimum {
    self.minimum = other.minimum
  }
  if other.maximum > self.maximum {
    self.maximum = other.maximum
  }
}

///|
pub fn OnlineMoments::summary(
  self : OnlineMoments,
  median? : Double = 0.0,
) -> StatsSummary {
  if self.count == 0 {
    StatsSummary::empty()
  } else {
    {
      count: self.count,
      mean: self.mean,
      variance: self.population_variance(),
      standard_deviation: self.standard_deviation(),
      minimum: self.minimum,
      maximum: self.maximum,
      median,
      first: self.minimum,
      last: self.maximum,
    }
  }
}

///|
/// Returns a sorted copy using insertion sort. It is stable and allocation-bounded for small windows.
pub fn sorted_copy(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  for value in values {
    let mut position = result.length()
    for i in 0..<result.length() {
      if value < result[i] {
        position = i
        break
      }
    }
    result.push(value)
    let mut i = result.length() - 1
    while i > position {
      result[i] = result[i - 1]
      i -= 1
    }
    result[position] = value
  }
  result
}

///|
pub fn sum(values : Array[Double]) -> Double {
  let mut result = 0.0
  for value in values {
    if is_finite(value) {
      result += value
    }
  }
  result
}

///|
pub fn array_minimum(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut result = values[0]
  for value in values {
    if is_finite(value) && value < result {
      result = value
    }
  }
  result
}

///|
pub fn array_maximum(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut result = values[0]
  for value in values {
    if is_finite(value) && value > result {
      result = value
    }
  }
  result
}

///|
pub fn mean(values : Array[Double]) -> Double {
  let accumulator = OnlineMoments::new()
  for value in values {
    accumulator.push(value)
  }
  accumulator.mean()
}

///|
pub fn variance(values : Array[Double]) -> Double {
  let accumulator = OnlineMoments::new()
  for value in values {
    accumulator.push(value)
  }
  accumulator.population_variance()
}

///|
pub fn standard_deviation(values : Array[Double]) -> Double {
  variance(values).sqrt()
}

///|
pub fn quantile(values : Array[Double], probability : Double) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = sorted_copy(values)
  let p = clamp_probability(probability)
  let position = p * (sorted.length() - 1).to_double()
  let lower = position.to_int()
  let upper = if lower + 1 < sorted.length() { lower + 1 } else { lower }
  let fraction = position - lower.to_double()
  sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
}

///|
pub fn median(values : Array[Double]) -> Double {
  quantile(values, 0.5)
}

///|
pub fn percentile(values : Array[Double], percent : Double) -> Double {
  quantile(values, percent / 100.0)
}

///|
pub fn interquartile_range(values : Array[Double]) -> Double {
  quantile(values, 0.75) - quantile(values, 0.25)
}

///|
pub fn median_absolute_deviation(values : Array[Double]) -> Double {
  let center = median(values)
  let deviations : Array[Double] = []
  for value in values {
    deviations.push(absolute(value - center))
  }
  median(deviations)
}

///|
pub fn trimmed_mean(values : Array[Double], trim_fraction : Double) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let sorted = sorted_copy(values)
  let fraction = clamp_probability(trim_fraction)
  let trim = (sorted.length().to_double() * fraction).to_int()
  let start = trim
  let end = sorted.length() - trim
  if start >= end {
    return median(sorted)
  }
  let selected : Array[Double] = []
  for i in start..<end {
    selected.push(sorted[i])
  }
  mean(selected)
}

///|
pub fn weighted_mean(values : Array[Double], weights : Array[Double]) -> Double {
  let length = if values.length() < weights.length() {
    values.length()
  } else {
    weights.length()
  }
  let mut total_weight = 0.0
  let mut total = 0.0
  for i in 0..<length {
    let weight = if weights[i] < 0.0 { 0.0 } else { weights[i] }
    total_weight += weight
    total += values[i] * weight
  }
  if total_weight == 0.0 {
    0.0
  } else {
    total / total_weight
  }
}

///|
pub fn covariance(left : Array[Double], right : Array[Double]) -> Double {
  let length = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  if length == 0 {
    return 0.0
  }
  let left_mean = mean(left)
  let right_mean = mean(right)
  let mut total = 0.0
  for i in 0..<length {
    total += (left[i] - left_mean) * (right[i] - right_mean)
  }
  total / length.to_double()
}

///|
pub fn correlation(left : Array[Double], right : Array[Double]) -> Double {
  let denominator = standard_deviation(left) * standard_deviation(right)
  if denominator == 0.0 {
    0.0
  } else {
    covariance(left, right) / denominator
  }
}

///|
pub fn linear_slope(values : Array[Double]) -> Double {
  let n = values.length()
  if n < 2 {
    return 0.0
  }
  let x_mean = (n - 1).to_double() / 2.0
  let y_mean = mean(values)
  let mut numerator = 0.0
  let mut denominator = 0.0
  for i in 0..<n {
    let x = i.to_double() - x_mean
    numerator += x * (values[i] - y_mean)
    denominator += x * x
  }
  if denominator == 0.0 {
    0.0
  } else {
    numerator / denominator
  }
}

///|
pub fn mean_absolute_difference(values : Array[Double]) -> Double {
  if values.length() < 2 {
    return 0.0
  }
  let mut total = 0.0
  for i in 1..<values.length() {
    total += absolute(values[i] - values[i - 1])
  }
  total / (values.length() - 1).to_double()
}

///|
pub fn autocorrelation(values : Array[Double], lag : Int) -> Double {
  if lag < 1 || lag >= values.length() {
    return 0.0
  }
  let center = mean(values)
  let mut numerator = 0.0
  let mut denominator = 0.0
  for i in 0..<values.length() {
    let d = values[i] - center
    denominator += d * d
  }
  for i in lag..<values.length() {
    numerator += (values[i] - center) * (values[i - lag] - center)
  }
  if denominator == 0.0 {
    0.0
  } else {
    numerator / denominator
  }
}
