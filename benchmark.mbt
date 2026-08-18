///|
/// Results of a deterministic detector benchmark.
pub struct BenchmarkResult {
  name : String
  samples : Int
  passes : Int
  detections : Int
  first_detection : Int
  checksum : Double
  truth_count : Int
  metrics : ChangePointMetrics
}

///|
pub fn BenchmarkResult::empty(name : String) -> BenchmarkResult {
  {
    name,
    samples: 0,
    passes: 0,
    detections: 0,
    first_detection: -1,
    checksum: 0.0,
    truth_count: 0,
    metrics: ChangePointMetrics::empty(),
  }
}

///|
pub fn BenchmarkResult::summary(self : BenchmarkResult) -> String {
  "\{self.name}: samples=\{self.samples},passes=\{self.passes},detections=\{self.detections},first=\{self.first_detection},precision=\{self.metrics.precision},recall=\{self.metrics.recall},f1=\{self.metrics.f1},checksum=\{self.checksum}"
}

///|
fn record_detection(
  result : DetectionResult,
  detections : Array[Int],
  first : Int,
) -> Int {
  if result.changed {
    detections.push(result.index)
    if first < 0 {
      result.index
    } else {
      first
    }
  } else {
    first
  }
}

///|
pub fn benchmark_cusum(
  scenario : SignalScenario,
  rounds? : Int = 1,
) -> BenchmarkResult {
  let values = generate_signal(scenario)
  let detections : Array[Int] = []
  let mut first = -1
  let mut checksum = 0.0
  let mut passes = 0
  let count = if rounds < 1 { 1 } else { rounds }
  for round in 0..<count {
    let detector = Cusum::new(
      target_mean=scenario.baseline,
      control_limit=5.0,
      drift=0.25,
    )
    for i, value in values {
      let result = detector.update_result(value, index=i)
      if round == 0 {
        first = record_detection(result, detections, first)
      }
      checksum += result.evidence
      passes += 1
    }
  }
  {
    name: "cusum",
    samples: values.length(),
    passes,
    detections: detections.length(),
    first_detection: first,
    checksum,
    truth_count: scenario_truth(scenario).length(),
    metrics: evaluate_change_points(
      detections,
      scenario_truth(scenario),
      tolerance=8,
    ),
  }
}

///|
pub fn benchmark_robust_z(
  scenario : SignalScenario,
  rounds? : Int = 1,
) -> BenchmarkResult {
  let values = generate_signal(scenario)
  let detections : Array[Int] = []
  let mut first = -1
  let mut checksum = 0.0
  let mut passes = 0
  let count = if rounds < 1 { 1 } else { rounds }
  for round in 0..<count {
    let detector = RobustZDetector::new(window_size=25, threshold=3.5)
    for i, value in values {
      ignore(i)
      let result = detector.update(value)
      if round == 0 {
        first = record_detection(result, detections, first)
      }
      checksum += result.evidence
      passes += 1
    }
  }
  {
    name: "robust-z",
    samples: values.length(),
    passes,
    detections: detections.length(),
    first_detection: first,
    checksum,
    truth_count: scenario_truth(scenario).length(),
    metrics: evaluate_change_points(
      detections,
      scenario_truth(scenario),
      tolerance=8,
    ),
  }
}

///|
pub fn benchmark_ensemble(
  scenario : SignalScenario,
  rounds? : Int = 1,
) -> BenchmarkResult {
  let values = generate_signal(scenario)
  let detections : Array[Int] = []
  let mut first = -1
  let mut checksum = 0.0
  let mut passes = 0
  let count = if rounds < 1 { 1 } else { rounds }
  for round in 0..<count {
    let detector = MultivariateEnsemble::new(
      [
        ProjectionDetector::new([1.0], threshold=3.0),
        ProjectionDetector::new([1.0], threshold=4.0),
      ],
      quorum=1,
    )
    for i, value in values {
      ignore(i)
      let result = detector.update([value])
      if round == 0 {
        first = record_detection(result, detections, first)
      }
      checksum += result.evidence
      passes += 1
    }
  }
  {
    name: "projection-ensemble",
    samples: values.length(),
    passes,
    detections: detections.length(),
    first_detection: first,
    checksum,
    truth_count: scenario_truth(scenario).length(),
    metrics: evaluate_change_points(
      detections,
      scenario_truth(scenario),
      tolerance=8,
    ),
  }
}

///|
/// Runs the standard acceptance benchmark suite on a fixed synthetic scenario.
pub fn benchmark_suite(rounds? : Int = 1) -> Array[BenchmarkResult] {
  let scenario = SignalScenario::mean_and_variance(
    length=512,
    change_at=256,
    baseline=10.0,
    shift=2.0,
    noise=0.15,
    post_noise=0.7,
    seed=20260818L,
  )
  [
    benchmark_cusum(scenario, rounds~),
    benchmark_robust_z(scenario, rounds~),
    benchmark_ensemble(scenario, rounds~),
  ]
}

///|
pub fn benchmark_markdown(results : Array[BenchmarkResult]) -> String {
  let mut output = "| detector | samples | passes | detections | first detection | precision | recall | F1 | checksum |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|\n"
  for result in results {
    output = output +
      "| \{result.name} | \{result.samples} | \{result.passes} | \{result.detections} | \{result.first_detection} | \{result.metrics.precision} | \{result.metrics.recall} | \{result.metrics.f1} | \{result.checksum} |\n"
  }
  output
}
