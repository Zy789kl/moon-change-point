///|
/// A detector that can be selected for a production metric pipeline.
pub(all) enum PipelineDetector {
  LegacyDetector(Detector)
  Ewma(EwmaDetector)
  RobustZ(RobustZDetector)
  VarianceShift(VarianceShiftDetector)
  TrendShift(TrendShiftDetector)
  IqrSpike(IqrSpikeDetector)
}

///|
pub fn PipelineDetector::update(
  self : PipelineDetector,
  value : Double,
  index : Int,
) -> DetectionResult {
  match self {
    LegacyDetector(detector) => detector.update_result(value, index~)
    Ewma(detector) => detector.update(value)
    RobustZ(detector) => detector.update(value)
    VarianceShift(detector) => detector.update(value)
    TrendShift(detector) => detector.update(value)
    IqrSpike(detector) => detector.update(value)
  }
}

///|
/// Controls deduplication, minimum severity, and recovery for one metric.
pub struct AlertPolicy {
  minimum_score : Double
  minimum_confidence : Double
  minimum_gap : Int
  recovery_points : Int
  mut quiet_points : Int
  mut healthy_points : Int
}

///|
pub fn AlertPolicy::new(
  minimum_score? : Double = 1.0,
  minimum_confidence? : Double = 0.5,
  minimum_gap? : Int = 5,
  recovery_points? : Int = 2,
) -> AlertPolicy {
  {
    minimum_score: if minimum_score < 0.0 {
      0.0
    } else {
      minimum_score
    },
    minimum_confidence: clamp_probability(minimum_confidence),
    minimum_gap: if minimum_gap < 0 {
      0
    } else {
      minimum_gap
    },
    recovery_points: if recovery_points < 1 {
      1
    } else {
      recovery_points
    },
    quiet_points: 0,
    healthy_points: 0,
  }
}

///|
pub fn AlertPolicy::reset(self : AlertPolicy) -> Unit {
  self.quiet_points = 0
  self.healthy_points = 0
}

///|
pub fn AlertPolicy::minimum_score(self : AlertPolicy) -> Double {
  self.minimum_score
}

///|
pub fn AlertPolicy::accept(
  self : AlertPolicy,
  result : DetectionResult,
) -> Bool {
  if !result.changed ||
    result.score < self.minimum_score ||
    result.confidence < self.minimum_confidence {
    self.healthy_points += 1
    if self.healthy_points >= self.recovery_points {
      self.quiet_points = 0
    }
    return false
  }
  self.healthy_points = 0
  if self.quiet_points > 0 {
    self.quiet_points -= 1
    return false
  }
  self.quiet_points = self.minimum_gap
  true
}

///|
/// One named metric with a detector and an alert policy.
pub struct MetricPipeline {
  name : String
  detector : PipelineDetector
  policy : AlertPolicy
  mut index : Int
  mut ordinal : Int
  baseline : Double
}

///|
pub fn MetricPipeline::new(
  name : String,
  detector : PipelineDetector,
  policy? : AlertPolicy = AlertPolicy::new(),
  baseline? : Double = 0.0,
) -> MetricPipeline {
  { name, detector, policy, index: 0, ordinal: 0, baseline }
}

///|
pub fn MetricPipeline::index(self : MetricPipeline) -> Int {
  self.index
}

///|
pub fn MetricPipeline::process(
  self : MetricPipeline,
  timestamp : Int64,
  value : Double,
) -> AlertEvent? {
  self.index += 1
  let result = self.detector.update(value, self.index)
  if result.changed {
    let point = SignalPoint::new(timestamp, value, sequence=self.index)
    let change = ChangePoint::from_result(
      point,
      result,
      self.name,
      self.baseline,
    )
    let accepted = self.policy.accept(result)
    self.ordinal += 1
    Some(
      AlertEvent::new(
        self.name,
        change,
        suppressed=!accepted,
        ordinal=self.ordinal,
      ),
    )
  } else {
    ignore(self.policy.accept(result))
    None
  }
}

///|
pub fn MetricPipeline::reset(self : MetricPipeline) -> Unit {
  self.index = 0
  self.ordinal = 0
  self.policy.reset()
}

///|
/// A deterministic multi-metric monitor. It is intentionally array-backed for WASM portability.
pub struct MultiMetricMonitor {
  pipelines : Array[MetricPipeline]
  mut processed : Int
  mut emitted : Int
  mut suppressed : Int
}

///|
pub fn MultiMetricMonitor::new(
  pipelines : Array[MetricPipeline],
) -> MultiMetricMonitor {
  { pipelines, processed: 0, emitted: 0, suppressed: 0 }
}

///|
pub fn MultiMetricMonitor::metric_count(self : MultiMetricMonitor) -> Int {
  self.pipelines.length()
}

///|
pub fn MultiMetricMonitor::processed_count(self : MultiMetricMonitor) -> Int {
  self.processed
}

///|
pub fn MultiMetricMonitor::emitted_count(self : MultiMetricMonitor) -> Int {
  self.emitted
}

///|
pub fn MultiMetricMonitor::suppressed_count(self : MultiMetricMonitor) -> Int {
  self.suppressed
}

///|
pub fn MultiMetricMonitor::process(
  self : MultiMetricMonitor,
  metric_index : Int,
  timestamp : Int64,
  value : Double,
) -> AlertEvent? {
  self.processed += 1
  if metric_index < 0 || metric_index >= self.pipelines.length() {
    return None
  }
  let event = self.pipelines[metric_index].process(timestamp, value)
  match event {
    None => None
    Some(alert) => {
      if alert.suppressed {
        self.suppressed += 1
      } else {
        self.emitted += 1
      }
      Some(alert)
    }
  }
}

///|
pub fn MultiMetricMonitor::process_batch(
  self : MultiMetricMonitor,
  metric_index : Int,
  points : Array[SignalPoint],
) -> Array[AlertEvent] {
  let result : Array[AlertEvent] = []
  for point in points {
    match self.process(metric_index, point.timestamp, point.value) {
      None => ()
      Some(event) => result.push(event)
    }
  }
  result
}
