///|
/// Confusion counts for a thresholded change-point decision stream.
pub struct ProductionConfusionMatrix {
  mut true_positive : Int
  mut false_positive : Int
  mut true_negative : Int
  mut false_negative : Int
}

///|
pub fn ProductionConfusionMatrix::empty() -> ProductionConfusionMatrix {
  { true_positive: 0, false_positive: 0, true_negative: 0, false_negative: 0 }
}

///|
pub fn ProductionConfusionMatrix::from_scores(
  scores : Array[Double],
  labels : Array[Bool],
  threshold : Double,
) -> ProductionConfusionMatrix {
  let matrix = ProductionConfusionMatrix::empty()
  let n = if scores.length() < labels.length() {
    scores.length()
  } else {
    labels.length()
  }
  for i in 0..<n {
    let predicted = is_finite(scores[i]) && scores[i] >= threshold
    if predicted && labels[i] {
      matrix.true_positive += 1
    } else if predicted && !labels[i] {
      matrix.false_positive += 1
    } else if !predicted && labels[i] {
      matrix.false_negative += 1
    } else {
      matrix.true_negative += 1
    }
  }
  matrix
}

///|
pub fn ProductionConfusionMatrix::true_positive(
  self : ProductionConfusionMatrix,
) -> Int {
  self.true_positive
}

///|
pub fn ProductionConfusionMatrix::false_positive(
  self : ProductionConfusionMatrix,
) -> Int {
  self.false_positive
}

///|
pub fn ProductionConfusionMatrix::true_negative(
  self : ProductionConfusionMatrix,
) -> Int {
  self.true_negative
}

///|
pub fn ProductionConfusionMatrix::false_negative(
  self : ProductionConfusionMatrix,
) -> Int {
  self.false_negative
}

///|
pub fn ProductionConfusionMatrix::support(
  self : ProductionConfusionMatrix,
) -> Int {
  self.true_positive +
  self.false_positive +
  self.true_negative +
  self.false_negative
}

///|
pub fn ProductionConfusionMatrix::precision(
  self : ProductionConfusionMatrix,
) -> Double {
  let denominator = self.true_positive + self.false_positive
  if denominator == 0 {
    0.0
  } else {
    self.true_positive.to_double() / denominator.to_double()
  }
}

///|
pub fn ProductionConfusionMatrix::recall(
  self : ProductionConfusionMatrix,
) -> Double {
  let denominator = self.true_positive + self.false_negative
  if denominator == 0 {
    0.0
  } else {
    self.true_positive.to_double() / denominator.to_double()
  }
}

///|
pub fn ProductionConfusionMatrix::specificity(
  self : ProductionConfusionMatrix,
) -> Double {
  let denominator = self.true_negative + self.false_positive
  if denominator == 0 {
    0.0
  } else {
    self.true_negative.to_double() / denominator.to_double()
  }
}

///|
pub fn ProductionConfusionMatrix::f1(
  self : ProductionConfusionMatrix,
) -> Double {
  let precision = self.precision()
  let recall = self.recall()
  if precision + recall == 0.0 {
    0.0
  } else {
    2.0 * precision * recall / (precision + recall)
  }
}

///|
pub fn ProductionConfusionMatrix::balanced_accuracy(
  self : ProductionConfusionMatrix,
) -> Double {
  (self.recall() + self.specificity()) / 2.0
}

///|
pub fn ProductionConfusionMatrix::false_positive_rate(
  self : ProductionConfusionMatrix,
) -> Double {
  1.0 - self.specificity()
}

///|
pub fn ProductionConfusionMatrix::summary(
  self : ProductionConfusionMatrix,
) -> String {
  "tp=" +
  self.true_positive.to_string() +
  ",fp=" +
  self.false_positive.to_string() +
  ",tn=" +
  self.true_negative.to_string() +
  ",fn=" +
  self.false_negative.to_string() +
  ",precision=" +
  self.precision().to_string() +
  ",recall=" +
  self.recall().to_string() +
  ",f1=" +
  self.f1().to_string()
}

///|
/// A point on a threshold evaluation curve.
pub struct ProductionCurvePoint {
  threshold : Double
  precision : Double
  recall : Double
  f1 : Double
  false_positive_rate : Double
  support : Int
}

///|
pub fn ProductionCurvePoint::from_matrix(
  threshold : Double,
  matrix : ProductionConfusionMatrix,
) -> ProductionCurvePoint {
  {
    threshold,
    precision: matrix.precision(),
    recall: matrix.recall(),
    f1: matrix.f1(),
    false_positive_rate: matrix.false_positive_rate(),
    support: matrix.support(),
  }
}

///|
pub fn ProductionCurvePoint::threshold(self : ProductionCurvePoint) -> Double {
  self.threshold
}

///|
pub fn ProductionCurvePoint::precision(self : ProductionCurvePoint) -> Double {
  self.precision
}

///|
pub fn ProductionCurvePoint::recall(self : ProductionCurvePoint) -> Double {
  self.recall
}

///|
pub fn ProductionCurvePoint::f1(self : ProductionCurvePoint) -> Double {
  self.f1
}

///|
pub fn ProductionCurvePoint::false_positive_rate(
  self : ProductionCurvePoint,
) -> Double {
  self.false_positive_rate
}

///|
pub fn ProductionCurvePoint::support(self : ProductionCurvePoint) -> Int {
  self.support
}

///|
/// Cost weights used to select an operating threshold.
pub struct ProductionThresholdCost {
  false_positive : Double
  false_negative : Double
  alert_volume : Double
}

///|
pub fn ProductionThresholdCost::new(
  false_positive? : Double = 1.0,
  false_negative? : Double = 5.0,
  alert_volume? : Double = 0.1,
) -> ProductionThresholdCost {
  {
    false_positive: if false_positive < 0.0 {
      0.0
    } else {
      false_positive
    },
    false_negative: if false_negative < 0.0 {
      0.0
    } else {
      false_negative
    },
    alert_volume: if alert_volume < 0.0 {
      0.0
    } else {
      alert_volume
    },
  }
}

///|
pub fn ProductionThresholdCost::score(
  self : ProductionThresholdCost,
  matrix : ProductionConfusionMatrix,
) -> Double {
  self.false_positive * matrix.false_positive().to_double() +
  self.false_negative * matrix.false_negative().to_double() +
  self.alert_volume * matrix.true_positive().to_double()
}

///|
pub fn ProductionThresholdCost::false_positive(
  self : ProductionThresholdCost,
) -> Double {
  self.false_positive
}

///|
pub fn ProductionThresholdCost::false_negative(
  self : ProductionThresholdCost,
) -> Double {
  self.false_negative
}

///|
pub fn ProductionThresholdCost::alert_volume(
  self : ProductionThresholdCost,
) -> Double {
  self.alert_volume
}

///|
/// Result of threshold selection on labeled historical data.
pub struct ProductionThresholdSelection {
  threshold : Double
  matrix : ProductionConfusionMatrix
  objective : Double
  strategy : String
}

///|
pub fn ProductionThresholdSelection::threshold(
  self : ProductionThresholdSelection,
) -> Double {
  self.threshold
}

///|
pub fn ProductionThresholdSelection::matrix(
  self : ProductionThresholdSelection,
) -> ProductionConfusionMatrix {
  self.matrix
}

///|
pub fn ProductionThresholdSelection::objective(
  self : ProductionThresholdSelection,
) -> Double {
  self.objective
}

///|
pub fn ProductionThresholdSelection::strategy(
  self : ProductionThresholdSelection,
) -> String {
  self.strategy
}

///|
pub fn production_threshold_grid(
  scores : Array[Double],
  steps? : Int = 32,
) -> Array[Double] {
  let finite : Array[Double] = []
  for score in scores {
    if is_finite(score) {
      finite.push(score)
    }
  }
  if finite.length() == 0 {
    return [0.0]
  }
  let low = array_minimum(finite)
  let high = array_maximum(finite)
  let count = if steps < 2 { 2 } else { steps }
  let result : Array[Double] = []
  if high <= low {
    result.push(low)
    return result
  }
  for i in 0..<=count {
    result.push(low + (high - low) * i.to_double() / count.to_double())
  }
  result
}

///|
pub fn production_select_f1_threshold(
  scores : Array[Double],
  labels : Array[Bool],
  steps? : Int = 32,
) -> ProductionThresholdSelection {
  let grid = production_threshold_grid(scores, steps~)
  let mut best : ProductionThresholdSelection = {
    threshold: grid[0],
    matrix: ProductionConfusionMatrix::from_scores(scores, labels, grid[0]),
    objective: -1.0,
    strategy: "f1",
  }
  for threshold in grid {
    let matrix = ProductionConfusionMatrix::from_scores(
      scores, labels, threshold,
    )
    let score = matrix.f1()
    if score > best.objective ||
      (score == best.objective && threshold < best.threshold) {
      best = { threshold, matrix, objective: score, strategy: "f1" }
    }
  }
  best
}

///|
pub fn production_select_cost_threshold(
  scores : Array[Double],
  labels : Array[Bool],
  cost? : ProductionThresholdCost = ProductionThresholdCost::new(),
  steps? : Int = 32,
) -> ProductionThresholdSelection {
  let grid = production_threshold_grid(scores, steps~)
  let mut best : ProductionThresholdSelection = {
    threshold: grid[0],
    matrix: ProductionConfusionMatrix::from_scores(scores, labels, grid[0]),
    objective: 1.0e308,
    strategy: "cost",
  }
  for threshold in grid {
    let matrix = ProductionConfusionMatrix::from_scores(
      scores, labels, threshold,
    )
    let score = cost.score(matrix)
    if score < best.objective ||
      (score == best.objective && threshold > best.threshold) {
      best = { threshold, matrix, objective: score, strategy: "cost" }
    }
  }
  best
}

///|
pub fn production_precision_recall_curve(
  scores : Array[Double],
  labels : Array[Bool],
  steps? : Int = 32,
) -> Array[ProductionCurvePoint] {
  let result : Array[ProductionCurvePoint] = []
  for threshold in production_threshold_grid(scores, steps~) {
    result.push(
      ProductionCurvePoint::from_matrix(
        threshold,
        ProductionConfusionMatrix::from_scores(scores, labels, threshold),
      ),
    )
  }
  result
}

///|
pub fn production_roc_curve(
  scores : Array[Double],
  labels : Array[Bool],
  steps? : Int = 32,
) -> Array[ProductionCurvePoint] {
  production_precision_recall_curve(scores, labels, steps~)
}

///|
/// Brier score for probabilistic change likelihoods.
pub fn production_brier_score(
  probabilities : Array[Double],
  labels : Array[Bool],
) -> Double {
  let n = if probabilities.length() < labels.length() {
    probabilities.length()
  } else {
    labels.length()
  }
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<n {
    let probability = clamp_probability(probabilities[i])
    let truth = if labels[i] { 1.0 } else { 0.0 }
    let error = probability - truth
    total += error * error
  }
  total / n.to_double()
}

///|
/// Numerically stable binary log loss.
pub fn production_log_loss(
  probabilities : Array[Double],
  labels : Array[Bool],
) -> Double {
  let n = if probabilities.length() < labels.length() {
    probabilities.length()
  } else {
    labels.length()
  }
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<n {
    let probability = if probabilities[i] < 1.0e-12 {
      1.0e-12
    } else if probabilities[i] > 1.0 - 1.0e-12 {
      1.0 - 1.0e-12
    } else {
      probabilities[i]
    }
    total += if labels[i] {
      -@math.ln(probability)
    } else {
      -@math.ln(1.0 - probability)
    }
  }
  total / n.to_double()
}

///|
/// A reliability bin used to audit score calibration.
pub struct ProductionCalibrationBin {
  lower : Double
  upper : Double
  count : Int
  positives : Int
  mean_score : Double
  observed_rate : Double
}

///|
pub fn ProductionCalibrationBin::lower(
  self : ProductionCalibrationBin,
) -> Double {
  self.lower
}

///|
pub fn ProductionCalibrationBin::upper(
  self : ProductionCalibrationBin,
) -> Double {
  self.upper
}

///|
pub fn ProductionCalibrationBin::count(self : ProductionCalibrationBin) -> Int {
  self.count
}

///|
pub fn ProductionCalibrationBin::positives(
  self : ProductionCalibrationBin,
) -> Int {
  self.positives
}

///|
pub fn ProductionCalibrationBin::mean_score(
  self : ProductionCalibrationBin,
) -> Double {
  self.mean_score
}

///|
pub fn ProductionCalibrationBin::observed_rate(
  self : ProductionCalibrationBin,
) -> Double {
  self.observed_rate
}

///|
pub fn production_calibration_bins(
  probabilities : Array[Double],
  labels : Array[Bool],
  bins? : Int = 10,
) -> Array[ProductionCalibrationBin] {
  let count = if bins < 1 { 1 } else { bins }
  let n = if probabilities.length() < labels.length() {
    probabilities.length()
  } else {
    labels.length()
  }
  let totals = Array::make(count, 0)
  let positives = Array::make(count, 0)
  let sums = Array::make(count, 0.0)
  for i in 0..<n {
    let probability = clamp_probability(probabilities[i])
    let index = if probability >= 1.0 {
      count - 1
    } else {
      (probability * count.to_double()).to_int()
    }
    totals[index] += 1
    sums[index] += probability
    if labels[i] {
      positives[index] += 1
    }
  }
  let result : Array[ProductionCalibrationBin] = []
  for i in 0..<count {
    let lower = i.to_double() / count.to_double()
    let upper = (i + 1).to_double() / count.to_double()
    result.push({
      lower,
      upper,
      count: totals[i],
      positives: positives[i],
      mean_score: if totals[i] == 0 {
        0.0
      } else {
        sums[i] / totals[i].to_double()
      },
      observed_rate: if totals[i] == 0 {
        0.0
      } else {
        positives[i].to_double() / totals[i].to_double()
      },
    })
  }
  result
}

///|
/// A summary of baseline/current distribution drift.
pub struct ProductionDriftReport {
  baseline_count : Int
  current_count : Int
  mean_shift : Double
  variance_ratio : Double
  ks_distance : Double
  energy_distance : Double
  drift_score : Double
  drifted : Bool
}

///|
pub fn ProductionDriftReport::from_values(
  baseline : Array[Double],
  current : Array[Double],
  threshold? : Double = 0.5,
) -> ProductionDriftReport {
  let baseline_mean = mean(baseline)
  let current_mean = mean(current)
  let baseline_variance = variance(baseline)
  let current_variance = variance(current)
  let ratio = if baseline_variance < 1.0e-12 {
    if current_variance > 0.0 {
      1.0e6
    } else {
      1.0
    }
  } else {
    current_variance / baseline_variance
  }
  let mean_scale = if standard_deviation(baseline) < 1.0e-12 {
    1.0
  } else {
    standard_deviation(baseline)
  }
  let mean_shift = absolute(current_mean - baseline_mean) / mean_scale
  let ks = ks_statistic(baseline, current)
  let energy = energy_distance(baseline, current)
  let score = clamp_probability(
    mean_shift / (mean_shift + 1.0) * 0.4 +
    ks * 0.4 +
    energy / (energy + 1.0) * 0.2,
  )
  {
    baseline_count: baseline.length(),
    current_count: current.length(),
    mean_shift,
    variance_ratio: ratio,
    ks_distance: ks,
    energy_distance: energy,
    drift_score: score,
    drifted: score >= threshold,
  }
}

///|
pub fn ProductionDriftReport::baseline_count(
  self : ProductionDriftReport,
) -> Int {
  self.baseline_count
}

///|
pub fn ProductionDriftReport::current_count(
  self : ProductionDriftReport,
) -> Int {
  self.current_count
}

///|
pub fn ProductionDriftReport::mean_shift(
  self : ProductionDriftReport,
) -> Double {
  self.mean_shift
}

///|
pub fn ProductionDriftReport::variance_ratio(
  self : ProductionDriftReport,
) -> Double {
  self.variance_ratio
}

///|
pub fn ProductionDriftReport::ks_distance(
  self : ProductionDriftReport,
) -> Double {
  self.ks_distance
}

///|
pub fn ProductionDriftReport::energy_distance(
  self : ProductionDriftReport,
) -> Double {
  self.energy_distance
}

///|
pub fn ProductionDriftReport::drift_score(
  self : ProductionDriftReport,
) -> Double {
  self.drift_score
}

///|
pub fn ProductionDriftReport::drifted(self : ProductionDriftReport) -> Bool {
  self.drifted
}

///|
pub fn ProductionDriftReport::summary(self : ProductionDriftReport) -> String {
  "baseline=" +
  self.baseline_count.to_string() +
  ",current=" +
  self.current_count.to_string() +
  ",mean_shift=" +
  self.mean_shift.to_string() +
  ",variance_ratio=" +
  self.variance_ratio.to_string() +
  ",ks=" +
  self.ks_distance.to_string() +
  ",score=" +
  self.drift_score.to_string() +
  ",drifted=" +
  self.drifted.to_string()
}
