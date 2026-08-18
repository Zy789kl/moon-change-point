///|
/// A validated vector observation for multivariate streams.
pub struct VectorPoint {
  timestamp : Int64
  values : Array[Double]
  sequence : Int
}

///|
pub fn VectorPoint::new(
  timestamp : Int64,
  values : Array[Double],
  sequence? : Int = 0,
) -> VectorPoint {
  let copy : Array[Double] = []
  for value in values {
    copy.push(value)
  }
  { timestamp, values: copy, sequence }
}

///|
pub fn VectorPoint::dimension(self : VectorPoint) -> Int {
  self.values.length()
}

///|
pub fn VectorPoint::is_valid(self : VectorPoint) -> Bool {
  for value in self.values {
    if !is_finite(value) {
      return false
    }
  }
  true
}

///|
/// Computes the Euclidean norm of a vector.
pub fn vector_norm(values : Array[Double]) -> Double {
  let mut total = 0.0
  for value in values {
    total += value * value
  }
  total.sqrt()
}

///|
pub fn vector_dot(left : Array[Double], right : Array[Double]) -> Double {
  let length = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut total = 0.0
  for i in 0..<length {
    total += left[i] * right[i]
  }
  total
}

///|
pub fn euclidean_distance(
  left : Array[Double],
  right : Array[Double],
) -> Double {
  let length = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut total = 0.0
  for i in 0..<length {
    let difference = left[i] - right[i]
    total += difference * difference
  }
  total.sqrt()
}

///|
pub fn cosine_similarity(left : Array[Double], right : Array[Double]) -> Double {
  let denominator = vector_norm(left) * vector_norm(right)
  if denominator == 0.0 {
    0.0
  } else {
    vector_dot(left, right) / denominator
  }
}

///|
/// Per-dimension Welford statistics for a vector stream.
pub struct OnlineVectorStats {
  dimension : Int
  mut count : Int
  means : Array[Double]
  m2 : Array[Double]
  minima : Array[Double]
  maxima : Array[Double]
}

///|
pub fn OnlineVectorStats::new(dimension : Int) -> OnlineVectorStats {
  let safe_dimension = if dimension < 1 { 1 } else { dimension }
  {
    dimension: safe_dimension,
    count: 0,
    means: Array::make(safe_dimension, 0.0),
    m2: Array::make(safe_dimension, 0.0),
    minima: Array::make(safe_dimension, 0.0),
    maxima: Array::make(safe_dimension, 0.0),
  }
}

///|
pub fn OnlineVectorStats::dimension(self : OnlineVectorStats) -> Int {
  self.dimension
}

///|
pub fn OnlineVectorStats::count(self : OnlineVectorStats) -> Int {
  self.count
}

///|
pub fn OnlineVectorStats::push(
  self : OnlineVectorStats,
  values : Array[Double],
) -> Bool {
  if values.length() != self.dimension {
    return false
  }
  for value in values {
    if !is_finite(value) {
      return false
    }
  }
  self.count += 1
  for i in 0..<self.dimension {
    let value = values[i]
    if self.count == 1 {
      self.means[i] = value
      self.minima[i] = value
      self.maxima[i] = value
    } else {
      let delta = value - self.means[i]
      self.means[i] += delta / self.count.to_double()
      self.m2[i] += delta * (value - self.means[i])
      if value < self.minima[i] {
        self.minima[i] = value
      }
      if value > self.maxima[i] {
        self.maxima[i] = value
      }
    }
  }
  true
}

///|
pub fn OnlineVectorStats::means(self : OnlineVectorStats) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.means {
    result.push(value)
  }
  result
}

///|
pub fn OnlineVectorStats::variances(self : OnlineVectorStats) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<self.dimension {
    result.push(
      if self.count == 0 {
        0.0
      } else {
        self.m2[i] / self.count.to_double()
      },
    )
  }
  result
}

///|
pub fn OnlineVectorStats::standard_deviations(
  self : OnlineVectorStats,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.variances() {
    result.push(value.sqrt())
  }
  result
}

///|
pub fn OnlineVectorStats::minimums(self : OnlineVectorStats) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.minima {
    result.push(value)
  }
  result
}

///|
pub fn OnlineVectorStats::maximums(self : OnlineVectorStats) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.maxima {
    result.push(value)
  }
  result
}

///|
pub fn OnlineVectorStats::standardized(
  self : OnlineVectorStats,
  values : Array[Double],
) -> Array[Double] {
  let result : Array[Double] = []
  let deviations = self.standard_deviations()
  for i in 0..<self.dimension {
    let scale = if deviations[i] < 1.0e-12 { 1.0 } else { deviations[i] }
    let center = self.means[i]
    result.push((values[i] - center) / scale)
  }
  result
}

///|
/// Diagonal Mahalanobis detector. It remains usable when a full covariance matrix is unavailable.
pub struct MahalanobisDetector {
  stats : OnlineVectorStats
  threshold : Double
  warmup : Int
  mut index : Int
}

///|
pub fn MahalanobisDetector::new(
  dimension : Int,
  threshold? : Double = 3.0,
  warmup? : Int = 8,
) -> MahalanobisDetector {
  {
    stats: OnlineVectorStats::new(dimension),
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
    index: 0,
  }
}

///|
pub fn MahalanobisDetector::dimension(self : MahalanobisDetector) -> Int {
  self.stats.dimension()
}

///|
pub fn MahalanobisDetector::count(self : MahalanobisDetector) -> Int {
  self.stats.count()
}

///|
pub fn MahalanobisDetector::update(
  self : MahalanobisDetector,
  values : Array[Double],
) -> DetectionResult {
  self.index += 1
  if values.length() != self.stats.dimension() {
    return DetectionResult::quiet(index=self.index)
  }
  if self.stats.count() < self.warmup {
    if !self.stats.push(values) {
      return DetectionResult::quiet(index=self.index)
    }
    return DetectionResult::quiet(index=self.index)
  }
  let standardized = self.stats.standardized(values)
  let distance = vector_norm(standardized)
  let score = distance / self.threshold
  let result = DetectionResult::new(
    distance >= self.threshold,
    score,
    clamp_probability(1.0 - @math.exp(-distance / 2.0)),
    DistributionShift,
    self.index,
    evidence=distance,
  )
  ignore(self.stats.push(values))
  result
}

///|
/// Tracks a weighted projection of a vector and detects changes in both projection and energy.
pub struct ProjectionDetector {
  weights : Array[Double]
  mut baseline : Double
  mut variance : Double
  alpha : Double
  threshold : Double
  mut count : Int
  mut index : Int
}

///|
pub fn ProjectionDetector::new(
  weights : Array[Double],
  alpha? : Double = 0.1,
  threshold? : Double = 3.0,
) -> ProjectionDetector {
  let copy : Array[Double] = []
  for weight in weights {
    copy.push(weight)
  }
  {
    weights: copy,
    baseline: 0.0,
    variance: 1.0,
    alpha: clamp_probability(alpha),
    threshold: if threshold <= 0.0 {
      3.0
    } else {
      threshold
    },
    count: 0,
    index: 0,
  }
}

///|
pub fn ProjectionDetector::dimension(self : ProjectionDetector) -> Int {
  self.weights.length()
}

///|
pub fn ProjectionDetector::update(
  self : ProjectionDetector,
  values : Array[Double],
) -> DetectionResult {
  self.index += 1
  if values.length() != self.weights.length() {
    return DetectionResult::quiet(index=self.index)
  }
  let projection = vector_dot(values, self.weights)
  self.count += 1
  if self.count == 1 {
    self.baseline = projection
    return DetectionResult::quiet(index=self.index)
  }
  let residual = projection - self.baseline
  self.baseline += self.alpha * residual
  self.variance = (1.0 - self.alpha) *
    (self.variance + self.alpha * residual * residual)
  let scale = if self.variance.sqrt() < 1.0e-12 {
    1.0e-12
  } else {
    self.variance.sqrt()
  }
  let z = absolute(residual) / scale
  DetectionResult::new(
    z >= self.threshold,
    z / self.threshold,
    clamp_probability(z / (z + 1.0)),
    direction_for_delta(residual),
    self.index,
    evidence=projection,
  )
}

///|
/// An ensemble that combines several multivariate views with a quorum rule.
pub struct MultivariateEnsemble {
  detectors : Array[ProjectionDetector]
  quorum : Int
  mut index : Int
}

///|
pub fn MultivariateEnsemble::new(
  detectors : Array[ProjectionDetector],
  quorum? : Int = 1,
) -> MultivariateEnsemble {
  let safe_quorum = if quorum < 1 {
    1
  } else if quorum > detectors.length() {
    detectors.length()
  } else {
    quorum
  }
  { detectors, quorum: safe_quorum, index: 0 }
}

///|
pub fn MultivariateEnsemble::detector_count(self : MultivariateEnsemble) -> Int {
  self.detectors.length()
}

///|
pub fn MultivariateEnsemble::update(
  self : MultivariateEnsemble,
  values : Array[Double],
) -> DetectionResult {
  self.index += 1
  let mut changed = 0
  let mut best_score = 0.0
  let mut best_confidence = 0.0
  let mut best_direction = Unknown
  for detector in self.detectors {
    let result = detector.update(values)
    if result.changed {
      changed += 1
    }
    if result.score > best_score {
      best_score = result.score
      best_confidence = result.confidence
      best_direction = result.direction
    }
  }
  DetectionResult::new(
    changed >= self.quorum,
    best_score,
    best_confidence,
    best_direction,
    self.index,
    evidence=changed.to_double(),
  )
}
