///|
/// Detector selection for the production stack.
pub(all) enum ProductionDetectorKind {
  CusumStackDetector
  RobustZStackDetector
  EwmaStackDetector
  VarianceStackDetector
  TrendStackDetector
  SeasonalStackDetector
  DistributionStackDetector
}

///|
pub fn production_detector_kind_name(kind : ProductionDetectorKind) -> String {
  match kind {
    CusumStackDetector => "cusum"
    RobustZStackDetector => "robust-z"
    EwmaStackDetector => "ewma"
    VarianceStackDetector => "variance"
    TrendStackDetector => "trend"
    SeasonalStackDetector => "seasonal"
    DistributionStackDetector => "distribution"
  }
}

///|
/// One weighted vote from a detector stack.
pub struct ProductionDetectorVote {
  kind : ProductionDetectorKind
  result : DetectionResult
  weight : Double
  accepted : Bool
}

///|
pub fn ProductionDetectorVote::kind(
  self : ProductionDetectorVote,
) -> ProductionDetectorKind {
  self.kind
}

///|
pub fn ProductionDetectorVote::result(
  self : ProductionDetectorVote,
) -> DetectionResult {
  self.result
}

///|
pub fn ProductionDetectorVote::weight(self : ProductionDetectorVote) -> Double {
  self.weight
}

///|
pub fn ProductionDetectorVote::accepted(self : ProductionDetectorVote) -> Bool {
  self.accepted
}

///|
/// Result of a weighted, explainable ensemble pass.
pub struct ProductionStackResult {
  result : DetectionResult
  votes : Array[ProductionDetectorVote]
  agreement : Double
  strongest : ProductionDetectorKind
}

///|
pub fn ProductionStackResult::result(
  self : ProductionStackResult,
) -> DetectionResult {
  self.result
}

///|
pub fn ProductionStackResult::votes(
  self : ProductionStackResult,
) -> Array[ProductionDetectorVote] {
  let result : Array[ProductionDetectorVote] = []
  for vote in self.votes {
    result.push(vote)
  }
  result
}

///|
pub fn ProductionStackResult::agreement(self : ProductionStackResult) -> Double {
  self.agreement
}

///|
pub fn ProductionStackResult::strongest(
  self : ProductionStackResult,
) -> ProductionDetectorKind {
  self.strongest
}

///|
pub fn ProductionStackResult::summary(self : ProductionStackResult) -> String {
  "changed=" +
  self.result.changed.to_string() +
  ",score=" +
  self.result.score.to_string() +
  ",agreement=" +
  self.agreement.to_string() +
  ",strongest=" +
  production_detector_kind_name(self.strongest)
}

///|
/// An array-backed ensemble that keeps detector order stable across targets.
pub struct ProductionDetectorStack {
  kinds : Array[ProductionDetectorKind]
  detectors : Array[PipelineDetector]
  weights : Array[Double]
  minimum_votes : Int
  mut index : Int
}

///|
pub fn ProductionDetectorStack::new(
  kinds : Array[ProductionDetectorKind],
  detectors : Array[PipelineDetector],
  weights? : Array[Double] = [],
  minimum_votes? : Int = 1,
) -> ProductionDetectorStack {
  let n = if kinds.length() < detectors.length() {
    kinds.length()
  } else {
    detectors.length()
  }
  let safe_votes = if minimum_votes < 1 {
    1
  } else if minimum_votes > n {
    n
  } else {
    minimum_votes
  }
  let normalized : Array[Double] = []
  for i in 0..<n {
    normalized.push(
      if i < weights.length() && weights[i] > 0.0 {
        weights[i]
      } else {
        1.0
      },
    )
  }
  {
    kinds: kinds[:n].to_owned(),
    detectors: detectors[:n].to_owned(),
    weights: normalized,
    minimum_votes: safe_votes,
    index: 0,
  }
}

///|
pub fn ProductionDetectorStack::length(self : ProductionDetectorStack) -> Int {
  self.detectors.length()
}

///|
pub fn ProductionDetectorStack::index(self : ProductionDetectorStack) -> Int {
  self.index
}

///|
pub fn ProductionDetectorStack::update(
  self : ProductionDetectorStack,
  value : Double,
) -> ProductionStackResult {
  self.index += 1
  let votes : Array[ProductionDetectorVote] = []
  let mut total_weight = 0.0
  let mut changed_weight = 0.0
  let mut score_total = 0.0
  let mut confidence_total = 0.0
  let mut strongest = if self.kinds.length() == 0 {
    CusumStackDetector
  } else {
    self.kinds[0]
  }
  let mut strongest_score = 0.0
  let mut positive_count = 0
  for i in 0..<self.detectors.length() {
    let result = self.detectors[i].update(value, self.index)
    let weight = self.weights[i]
    let accepted = result.changed && result.score >= 1.0
    if accepted {
      positive_count += 1
    }
    if result.score > strongest_score {
      strongest_score = result.score
      strongest = self.kinds[i]
    }
    total_weight += weight
    if accepted {
      changed_weight += weight
    }
    score_total += result.score * weight
    confidence_total += result.confidence * weight
    votes.push({ kind: self.kinds[i], result, weight, accepted })
  }
  let safe_weight = if total_weight < 1.0e-12 { 1.0 } else { total_weight }
  let agreement = changed_weight / safe_weight
  let changed = positive_count >= self.minimum_votes
  let result = DetectionResult::new(
    changed,
    score_total / safe_weight,
    confidence_total / safe_weight,
    Unknown,
    self.index,
    evidence=agreement,
  )
  { result, votes, agreement, strongest }
}

///|
pub fn ProductionDetectorStack::reset(self : ProductionDetectorStack) -> Unit {
  self.index = 0
}

///|
/// Baseline-relative detector for services whose normal level changes gradually.
pub struct ProductionAdaptiveBaselineDetector {
  window : DoubleWindow
  learning_rate : Double
  threshold : Double
  warmup : Int
  mut baseline : Double
  mut index : Int
  mut initialized : Bool
}

///|
pub fn ProductionAdaptiveBaselineDetector::new(
  window_size? : Int = 32,
  learning_rate? : Double = 0.05,
  threshold? : Double = 3.0,
  warmup? : Int = 8,
) -> ProductionAdaptiveBaselineDetector {
  {
    window: DoubleWindow::new(if window_size < 2 { 2 } else { window_size }),
    learning_rate: clamp_probability(learning_rate),
    threshold: if threshold <= 0.0 {
      3.0
    } else {
      threshold
    },
    warmup: if warmup < 1 {
      1
    } else {
      warmup
    },
    baseline: 0.0,
    index: 0,
    initialized: false,
  }
}

///|
pub fn ProductionAdaptiveBaselineDetector::baseline(
  self : ProductionAdaptiveBaselineDetector,
) -> Double {
  self.baseline
}

///|
pub fn ProductionAdaptiveBaselineDetector::index(
  self : ProductionAdaptiveBaselineDetector,
) -> Int {
  self.index
}

///|
pub fn ProductionAdaptiveBaselineDetector::update(
  self : ProductionAdaptiveBaselineDetector,
  value : Double,
) -> DetectionResult {
  self.index += 1
  if !is_finite(value) {
    return DetectionResult::quiet(index=self.index)
  }
  if !self.initialized {
    ignore(self.window.push(value))
    self.baseline = self.window.mean()
    if self.window.length() >= self.warmup {
      self.initialized = true
    }
    return DetectionResult::quiet(index=self.index)
  }
  let residual = value - self.baseline
  let scale = self.window.standard_deviation()
  let safe_scale = if scale < 1.0e-12 { 1.0 } else { scale }
  let z = absolute(residual) / safe_scale
  let result = DetectionResult::new(
    z >= self.threshold,
    z / self.threshold,
    clamp_probability(z / (z + 1.0)),
    if residual > 0.0 {
      Increase
    } else if residual < 0.0 {
      Decrease
    } else {
      Unknown
    },
    self.index,
    evidence=residual,
  )
  self.baseline += self.learning_rate * residual
  ignore(self.window.push(value))
  result
}

///|
pub fn ProductionAdaptiveBaselineDetector::reset(
  self : ProductionAdaptiveBaselineDetector,
) -> Unit {
  self.window.clear()
  self.baseline = 0.0
  self.index = 0
  self.initialized = false
}

///|
/// A finite alert budget measured over a rolling event-time interval.
pub struct ProductionEventBudget {
  capacity : Int
  interval : Int64
  mut window_start : Int64?
  mut used : Int
  mut denied : Int
}

///|
pub fn ProductionEventBudget::new(
  capacity? : Int = 20,
  interval? : Int64 = 60L,
) -> ProductionEventBudget {
  {
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    interval: if interval < 1L {
      1L
    } else {
      interval
    },
    window_start: None,
    used: 0,
    denied: 0,
  }
}

///|
pub fn ProductionEventBudget::allow(
  self : ProductionEventBudget,
  timestamp : Int64,
) -> Bool {
  match self.window_start {
    None => self.window_start = Some(timestamp)
    Some(start) =>
      if timestamp - start >= self.interval {
        self.window_start = Some(timestamp)
        self.used = 0
      }
  }
  if self.used < self.capacity {
    self.used += 1
    true
  } else {
    self.denied += 1
    false
  }
}

///|
pub fn ProductionEventBudget::used(self : ProductionEventBudget) -> Int {
  self.used
}

///|
pub fn ProductionEventBudget::denied(self : ProductionEventBudget) -> Int {
  self.denied
}

///|
pub fn ProductionEventBudget::remaining(self : ProductionEventBudget) -> Int {
  if self.capacity > self.used {
    self.capacity - self.used
  } else {
    0
  }
}
