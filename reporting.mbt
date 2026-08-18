///|
/// Converts a detection result to a stable CSV row.
pub fn detection_csv(result : DetectionResult) -> String {
  "\{result.index},\{result.changed},\{result.score},\{result.confidence},\{direction_name(result.direction)},\{result.evidence}"
}

///|
pub fn change_point_csv(point : ChangePoint) -> String {
  "\{point.timestamp},\{point.index},\{point.score},\{point.confidence},\{direction_name(point.direction)},\{severity_name(point.severity)},\{point.detector},\{point.baseline},\{point.observed}"
}

///|
pub fn detection_csv_header() -> String {
  "index,changed,score,confidence,direction,evidence"
}

///|
pub fn change_point_csv_header() -> String {
  "timestamp,index,score,confidence,direction,severity,detector,baseline,observed"
}

///|
pub fn results_csv(results : Array[DetectionResult]) -> String {
  let mut output = detection_csv_header() + "\n"
  for result in results {
    output = output + detection_csv(result) + "\n"
  }
  output
}

///|
pub fn changes_csv(points : Array[ChangePoint]) -> String {
  let mut output = change_point_csv_header() + "\n"
  for point in points {
    output = output + change_point_csv(point) + "\n"
  }
  output
}

///|
pub fn summary_markdown(summary : StatsSummary) -> String {
  "| count | mean | variance | stddev | min | median | max |\n|---:|---:|---:|---:|---:|---:|---:|\n| \{summary.count} | \{summary.mean} | \{summary.variance} | \{summary.standard_deviation} | \{summary.minimum} | \{summary.median} | \{summary.maximum} |"
}

///|
pub fn metrics_markdown(metrics : ChangePointMetrics) -> String {
  "| TP | FP | FN | precision | recall | F1 | mean delay |\n|---:|---:|---:|---:|---:|---:|---:|\n| \{metrics.true_positives} | \{metrics.false_positives} | \{metrics.false_negatives} | \{metrics.precision} | \{metrics.recall} | \{metrics.f1} | \{metrics.mean_detection_delay} |"
}

///|
pub fn alerts_markdown(alerts : Array[AlertEvent]) -> String {
  let mut output = "| metric | timestamp | direction | score | confidence | suppressed |\n|---|---:|---|---:|---:|---|\n"
  for alert in alerts {
    output = output +
      "| \{alert.metric} | \{alert.point.timestamp} | \{direction_name(alert.point.direction)} | \{alert.point.score} | \{alert.point.confidence} | \{alert.suppressed} |\n"
  }
  output
}
