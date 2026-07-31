///|
/// `DetectorType` represents the type of change point detector to use.
pub enum DetectorType {
  CusumDetector(Cusum)
  PageHinkleyDetector(PageHinkley)
  BayesianDetector(Bayesian)
}

///|
/// `Detector` wraps a specific algorithm and supports multi-metric alert suppression.
pub struct Detector {
  detector : DetectorType
  mut suppression_count : Int
  suppression_limit : Int
}

///|
/// Creates a new multi-metric detector wrapper.
pub fn Detector::new(
  detector : DetectorType,
  suppression_limit? : Int = 3,
) -> Detector {
  { detector, suppression_count: 0, suppression_limit }
}

///|
/// Updates the detector and handles alert suppression. Returns true if an unsuppressed alert is triggered.
pub fn Detector::update(self : Detector, value : Double) -> Bool {
  let detected = match self.detector {
    CusumDetector(c) => c.update(value)
    PageHinkleyDetector(p) => p.update(value)
    BayesianDetector(b) => b.update(value) > 0.5
  }

  if detected {
    if self.suppression_count < self.suppression_limit {
      self.suppression_count += 1
      return false // Suppressed
    } else {
      self.suppression_count = 0
      return true // Alert
    }
  } else if self.suppression_count > 0 {
    self.suppression_count -= 1
  }
  return false
}
