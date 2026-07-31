///|
/// `Cusum` implements the Cumulative Sum algorithm for detecting shifts in the mean.
pub struct Cusum {
  target_mean : Double
  control_limit : Double
  drift : Double
  mut g_positive : Double
  mut g_negative : Double
  mut t : Int
}

///|
/// Creates a new CUSUM detector.
pub fn Cusum::new(
  target_mean? : Double = 0.0,
  control_limit? : Double = 5.0,
  drift? : Double = 0.5,
) -> Cusum {
  { target_mean, control_limit, drift, g_positive: 0.0, g_negative: 0.0, t: 0 }
}

///|
/// Updates the CUSUM detector with a new value and returns true if a change is detected.
pub fn Cusum::update(self : Cusum, value : Double) -> Bool {
  self.t += 1
  let diff = value - self.target_mean

  // Update positive and negative accumulators
  self.g_positive = if self.g_positive + diff - self.drift > 0.0 {
    self.g_positive + diff - self.drift
  } else {
    0.0
  }
  self.g_negative = if self.g_negative - diff - self.drift > 0.0 {
    self.g_negative - diff - self.drift
  } else {
    0.0
  }

  if self.g_positive > self.control_limit ||
    self.g_negative > self.control_limit {
    self.reset()
    return true
  }
  return false
}

///|
/// Resets the internal accumulators.
pub fn Cusum::reset(self : Cusum) -> Unit {
  self.g_positive = 0.0
  self.g_negative = 0.0
}
