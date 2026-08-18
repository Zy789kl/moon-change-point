///|
/// A fixed-edge histogram for monitoring changes in value distribution.
pub struct Histogram {
  minimum : Double
  maximum : Double
  bins : Int
  counts : Array[Int]
  mut total : Int
}

///|
pub fn Histogram::new(
  minimum : Double,
  maximum : Double,
  bins : Int,
) -> Histogram {
  let safe_bins = if bins < 1 { 1 } else { bins }
  let high = if maximum <= minimum { minimum + 1.0 } else { maximum }
  {
    minimum,
    maximum: high,
    bins: safe_bins,
    counts: Array::make(safe_bins, 0),
    total: 0,
  }
}

///|
pub fn Histogram::bins(self : Histogram) -> Int {
  self.bins
}

///|
pub fn Histogram::total(self : Histogram) -> Int {
  self.total
}

///|
fn Histogram::bin_index(self : Histogram, value : Double) -> Int {
  if value <= self.minimum {
    0
  } else if value >= self.maximum {
    self.bins - 1
  } else {
    ((value - self.minimum) /
    (self.maximum - self.minimum) *
    self.bins.to_double()).to_int()
  }
}

///|
pub fn Histogram::push(self : Histogram, value : Double) -> Unit {
  if !is_finite(value) {
    return
  }
  let index = self.bin_index(value)
  self.counts[index] += 1
  self.total += 1
}

///|
pub fn Histogram::counts(self : Histogram) -> Array[Int] {
  let result : Array[Int] = []
  for count in self.counts {
    result.push(count)
  }
  result
}

///|
pub fn Histogram::probabilities(self : Histogram) -> Array[Double] {
  let result : Array[Double] = []
  for count in self.counts {
    result.push(
      if self.total == 0 {
        0.0
      } else {
        count.to_double() / self.total.to_double()
      },
    )
  }
  result
}

///|
pub fn Histogram::reset(self : Histogram) -> Unit {
  for i in 0..<self.counts.length() {
    self.counts[i] = 0
  }
  self.total = 0
}

///|
pub fn histogram_distance(left : Histogram, right : Histogram) -> Double {
  if left.bins() != right.bins() {
    return 0.0
  }
  let a = left.probabilities()
  let b = right.probabilities()
  let mut total = 0.0
  for i in 0..<a.length() {
    let difference = a[i] - b[i]
    total += difference * difference
  }
  total.sqrt()
}

///|
pub fn histogram_hellinger(left : Histogram, right : Histogram) -> Double {
  if left.bins() != right.bins() {
    return 0.0
  }
  let a = left.probabilities()
  let b = right.probabilities()
  let mut total = 0.0
  for i in 0..<a.length() {
    let difference = a[i].sqrt() - b[i].sqrt()
    total += difference * difference
  }
  (total / 2.0).sqrt()
}

///|
/// Kolmogorov-Smirnov distance between two samples.
pub fn ks_statistic(left : Array[Double], right : Array[Double]) -> Double {
  if left.length() == 0 || right.length() == 0 {
    return 0.0
  }
  let a = sorted_copy(left)
  let b = sorted_copy(right)
  let mut i = 0
  let mut j = 0
  let mut distance = 0.0
  while i < a.length() || j < b.length() {
    if j >= b.length() || (i < a.length() && a[i] <= b[j]) {
      i += 1
    } else {
      j += 1
    }
    let left_cdf = i.to_double() / a.length().to_double()
    let right_cdf = j.to_double() / b.length().to_double()
    let difference = absolute(left_cdf - right_cdf)
    if difference > distance {
      distance = difference
    }
  }
  distance
}

///|
pub fn energy_distance(left : Array[Double], right : Array[Double]) -> Double {
  if left.length() == 0 || right.length() == 0 {
    return 0.0
  }
  let mut cross = 0.0
  for x in left {
    for y in right {
      cross += absolute(x - y)
    }
  }
  cross = cross / (left.length() * right.length()).to_double()
  let mut within_left = 0.0
  for x in left {
    for y in left {
      within_left += absolute(x - y)
    }
  }
  within_left = within_left / (left.length() * left.length()).to_double()
  let mut within_right = 0.0
  for x in right {
    for y in right {
      within_right += absolute(x - y)
    }
  }
  within_right = within_right / (right.length() * right.length()).to_double()
  2.0 * cross - within_left - within_right
}

///|
pub fn distribution_overlap(
  left : Array[Double],
  right : Array[Double],
  bins? : Int = 16,
) -> Double {
  if left.length() == 0 || right.length() == 0 {
    return 0.0
  }
  let left_minimum = array_minimum(left)
  let right_minimum = array_minimum(right)
  let left_maximum = array_maximum(left)
  let right_maximum = array_maximum(right)
  let lower = if left_minimum < right_minimum {
    left_minimum
  } else {
    right_minimum
  }
  let upper = if left_maximum > right_maximum {
    left_maximum
  } else {
    right_maximum
  }
  let first = Histogram::new(lower, upper, bins)
  let second = Histogram::new(lower, upper, bins)
  for value in left {
    first.push(value)
  }
  for value in right {
    second.push(value)
  }
  let a = first.probabilities()
  let b = second.probabilities()
  let mut overlap = 0.0
  for i in 0..<a.length() {
    overlap += if a[i] < b[i] { a[i] } else { b[i] }
  }
  overlap
}

///|
pub fn quantile_shift_score(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  let p50 = absolute(median(left) - median(right))
  let p90 = absolute(quantile(left, 0.9) - quantile(right, 0.9))
  let scale = standard_deviation(left) + standard_deviation(right) + 1.0e-12
  (p50 + p90) / scale
}

///|
pub fn distribution_change_score(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  let ks = ks_statistic(left, right)
  let quantiles = quantile_shift_score(left, right)
  let energy = energy_distance(left, right)
  (ks + quantiles + (if energy > 0.0 { energy } else { 0.0 })) / 3.0
}

///|
/// Compares adjacent windows and emits a distribution-shift result.
pub struct DistributionShiftDetector {
  reference : DoubleWindow
  current : DoubleWindow
  threshold : Double
  mut index : Int
}

///|
pub fn DistributionShiftDetector::new(
  window_size? : Int = 32,
  threshold? : Double = 0.35,
) -> DistributionShiftDetector {
  let size = if window_size < 4 { 4 } else { window_size }
  {
    reference: DoubleWindow::new(size),
    current: DoubleWindow::new(size),
    threshold: if threshold <= 0.0 {
      0.35
    } else {
      threshold
    },
    index: 0,
  }
}

///|
pub fn DistributionShiftDetector::update(
  self : DistributionShiftDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  if self.current.is_full() {
    let old = self.current.to_array()
    self.reference.clear()
    for item in old {
      ignore(self.reference.push(item))
    }
    self.current.clear()
  }
  ignore(self.current.push(value))
  if !self.reference.is_full() || !self.current.is_full() {
    return DetectionResult::quiet(index=self.index)
  }
  let score = distribution_change_score(
    self.reference.to_array(),
    self.current.to_array(),
  )
  DetectionResult::new(
    score >= self.threshold,
    score / self.threshold,
    clamp_probability(score),
    DistributionShift,
    self.index,
    evidence=score,
  )
}
