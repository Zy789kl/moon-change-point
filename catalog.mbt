///|
/// Public algorithm metadata for dashboards and configuration UIs.
pub struct DetectorSpec {
  name : String
  family : String
  online : Bool
  multivariate : Bool
  robust : Bool
  default_threshold : Double
  description : String
}

///|
pub fn DetectorSpec::new(
  name : String,
  family : String,
  online : Bool,
  multivariate : Bool,
  robust : Bool,
  default_threshold : Double,
  description : String,
) -> DetectorSpec {
  { name, family, online, multivariate, robust, default_threshold, description }
}

///|
pub fn DetectorSpec::summary(self : DetectorSpec) -> String {
  self.name +
  " [" +
  self.family +
  "] threshold=" +
  self.default_threshold.to_string()
}

///|
pub fn detector_catalog() -> Array[DetectorSpec] {
  [
    DetectorSpec::new(
      "CUSUM", "sequential", true, false, false, 5.0, "small persistent mean shifts",
    ),
    DetectorSpec::new(
      "Page-Hinkley", "sequential", true, false, false, 10.0, "mean drift with forgetting",
    ),
    DetectorSpec::new(
      "Bayesian", "probabilistic", true, false, false, 0.5, "posterior change probability",
    ),
    DetectorSpec::new(
      "Robust-Z", "distribution", true, false, true, 3.5, "median and MAD based spikes",
    ),
    DetectorSpec::new(
      "Mahalanobis", "multivariate", true, true, true, 3.0, "vector distance from baseline",
    ),
    DetectorSpec::new(
      "Binary segmentation", "offline", false, false, false, 0.5, "multiple historical changes",
    ),
  ]
}

///|
pub fn detector_names() -> Array[String] {
  let result : Array[String] = []
  for spec in detector_catalog() {
    result.push(spec.name)
  }
  result
}

///|
pub fn find_detector(name : String) -> DetectorSpec? {
  for spec in detector_catalog() {
    if spec.name == name {
      return Some(spec)
    }
  }
  None
}

///|
pub fn online_detector_count() -> Int {
  let mut count = 0
  for spec in detector_catalog() {
    if spec.online {
      count += 1
    }
  }
  count
}

///|
pub fn robust_detector_count() -> Int {
  let mut count = 0
  for spec in detector_catalog() {
    if spec.robust {
      count += 1
    }
  }
  count
}

///|
pub fn catalog_markdown() -> String {
  let mut output = "| detector | family | online | multivariate | robust | threshold |\n|---|---|---|---|---|---:|\n"
  for spec in detector_catalog() {
    output = output +
      "| " +
      spec.name +
      " | " +
      spec.family +
      " | " +
      spec.online.to_string() +
      " | " +
      spec.multivariate.to_string() +
      " | " +
      spec.robust.to_string() +
      " | " +
      spec.default_threshold.to_string() +
      " |\n"
  }
  output
}

///|
pub fn recommended_detector(
  multivariate : Bool,
  offline : Bool,
  robust : Bool,
) -> String {
  if offline {
    "Binary segmentation"
  } else if multivariate {
    "Mahalanobis"
  } else if robust {
    "Robust-Z"
  } else {
    "CUSUM"
  }
}
