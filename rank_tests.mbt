///|
pub fn ranks(values : Array[Double]) -> Array[Double] {
  let sorted = sorted_copy(values)
  let result : Array[Double] = []
  for value in values {
    let mut first = 0
    let mut last = sorted.length() - 1
    while first <= last {
      let middle = (first + last) / 2
      if sorted[middle] < value {
        first = middle + 1
      } else {
        last = middle - 1
      }
    }
    result.push(first.to_double() + 1.0)
  }
  result
}

///|
pub fn spearman_correlation(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  correlation(ranks(left), ranks(right))
}

///|
pub fn mann_whitney_u(left : Array[Double], right : Array[Double]) -> Double {
  let ranks_right = sorted_copy(right)
  let mut u = 0.0
  for value in left {
    for other in ranks_right {
      if value > other {
        u += 1.0
      } else if value == other {
        u += 0.5
      }
    }
  }
  u
}

///|
pub fn rank_biserial_effect(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  if left.length() == 0 || right.length() == 0 {
    return 0.0
  }
  let u = mann_whitney_u(left, right)
  2.0 * u / (left.length() * right.length()).to_double() - 1.0
}

///|
pub fn sign_change_rate(values : Array[Double]) -> Double {
  if values.length() < 2 {
    return 0.0
  }
  let mut changes = 0
  let mut previous = sign(values[0])
  for i in 1..<values.length() {
    let current = sign(values[i])
    if current != 0 && previous != 0 && current != previous {
      changes += 1
    }
    if current != 0 {
      previous = current
    }
  }
  changes.to_double() / (values.length() - 1).to_double()
}

///|
pub fn runs_test_score(values : Array[Double]) -> Double {
  if values.length() < 2 {
    return 0.0
  }
  let center = median(values)
  let mut runs = 1
  let mut previous = values[0] >= center
  for i in 1..<values.length() {
    let current = values[i] >= center
    if current != previous {
      runs += 1
      previous = current
    }
  }
  runs.to_double() / values.length().to_double()
}

///|
pub fn slope_confidence(values : Array[Double]) -> Double {
  let slope = absolute(linear_slope(values))
  let noise = mean_absolute_difference(values) + 1.0e-12
  clamp_probability(slope / (slope + noise))
}

///|
pub struct RankShiftDetector {
  left : DoubleWindow
  right : DoubleWindow
  threshold : Double
  mut index : Int
}

///|
pub fn RankShiftDetector::new(
  window_size? : Int = 16,
  threshold? : Double = 0.25,
) -> RankShiftDetector {
  let size = if window_size < 2 { 2 } else { window_size }
  {
    left: DoubleWindow::new(size),
    right: DoubleWindow::new(size),
    threshold: if threshold <= 0.0 {
      0.25
    } else {
      threshold
    },
    index: 0,
  }
}

///|
pub fn RankShiftDetector::update(
  self : RankShiftDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  if self.right.is_full() {
    self.left.clear()
    for item in self.right.to_array() {
      ignore(self.left.push(item))
    }
    self.right.clear()
  }
  ignore(self.right.push(value))
  if !self.left.is_full() || !self.right.is_full() {
    return DetectionResult::quiet(index=self.index)
  }
  let effect = absolute(
    rank_biserial_effect(self.left.to_array(), self.right.to_array()),
  )
  DetectionResult::new(
    effect >= self.threshold,
    effect / self.threshold,
    clamp_probability(effect),
    DistributionShift,
    self.index,
    evidence=effect,
  )
}
