///|
/// `PageHinkley` implements the Page-Hinkley test for online change point detection.
pub struct PageHinkley {
  mut target_mean : Double
  control_limit : Double
  delta : Double
  alpha : Double
  mut sum : Double
  mut min_sum : Double
  mut n : Int
}

///|
/// Creates a new Page-Hinkley detector.
pub fn PageHinkley::new(
  target_mean? : Double = 0.0,
  control_limit? : Double = 10.0,
  delta? : Double = 0.5,
  alpha? : Double = 0.99,
) -> PageHinkley {
  { target_mean, control_limit, delta, alpha, sum: 0.0, min_sum: 0.0, n: 0 }
}

///|
/// Updates the Page-Hinkley detector with a new value and returns true if a change is detected.
pub fn PageHinkley::update(self : PageHinkley, value : Double) -> Bool {
  self.n += 1

  // Update the mean incrementally with forgetting factor alpha
  self.target_mean = self.target_mean * self.alpha + value * (1.0 - self.alpha)

  // Update cumulative sum
  self.sum += value - self.target_mean - self.delta

  if self.sum < self.min_sum {
    self.min_sum = self.sum
  }

  if self.sum - self.min_sum > self.control_limit {
    self.reset()
    return true
  }
  return false
}

///|
/// Resets the internal accumulators.
pub fn PageHinkley::reset(self : PageHinkley) -> Unit {
  self.sum = 0.0
  self.min_sum = 0.0
  self.n = 0
}

///|
/// Rich result form of `update`, retaining direction and cumulative evidence.
pub fn PageHinkley::update_result(
  self : PageHinkley,
  value : Double,
  index? : Int = 0,
) -> DetectionResult {
  let delta = value - self.target_mean
  let changed = self.update(value)
  let evidence = self.sum - self.min_sum
  let score = if self.control_limit <= 0.0 {
    0.0
  } else {
    evidence / self.control_limit
  }
  DetectionResult::new(
    changed,
    score,
    clamp_probability(score / (score + 1.0)),
    direction_for_delta(delta),
    index,
    evidence~,
  )
}
