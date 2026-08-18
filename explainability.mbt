///|
/// Structured evidence for explaining why a detector emitted an alert.
pub struct EvidenceContribution {
  name : String
  value : Double
  weight : Double
  contribution : Double
}

///|
pub fn EvidenceContribution::new(
  name : String,
  value : Double,
  weight? : Double = 1.0,
) -> EvidenceContribution {
  { name, value, weight, contribution: value * weight }
}

///|
pub struct DetectionExplanation {
  result : DetectionResult
  baseline : Double
  observed : Double
  deviation : Double
  relative_change : Double
  contributions : Array[EvidenceContribution]
  recommendation : String
}

///|
pub fn DetectionExplanation::empty(index? : Int = 0) -> DetectionExplanation {
  {
    result: DetectionResult::quiet(index~),
    baseline: 0.0,
    observed: 0.0,
    deviation: 0.0,
    relative_change: 0.0,
    contributions: [],
    recommendation: "collect more observations",
  }
}

///|
pub fn absolute_change(baseline : Double, observed : Double) -> Double {
  absolute(observed - baseline)
}

///|
pub fn relative_change(baseline : Double, observed : Double) -> Double {
  if baseline == 0.0 {
    absolute_change(baseline, observed)
  } else {
    absolute_change(baseline, observed) / absolute(baseline)
  }
}

///|
pub fn change_direction_from_values(
  baseline : Double,
  observed : Double,
) -> ChangeDirection {
  if observed > baseline {
    Increase
  } else if observed < baseline {
    Decrease
  } else {
    Unknown
  }
}

///|
pub fn evidence_strength(
  score : Double,
  confidence : Double,
  deviation : Double,
) -> Double {
  clamp_probability(
    (
      clamp_probability(score) +
      clamp_probability(confidence) +
      clamp_probability(deviation)
    ) /
    3.0,
  )
}

///|
pub fn make_explanation(
  result : DetectionResult,
  baseline : Double,
  observed : Double,
  detector : String,
) -> DetectionExplanation {
  let deviation = absolute_change(baseline, observed)
  let relative = relative_change(baseline, observed)
  let direction = change_direction_from_values(baseline, observed)
  let direction_score = if direction_name(direction) == "increase" ||
    direction_name(direction) == "decrease" {
    relative
  } else {
    0.0
  }
  let contributions = [
    EvidenceContribution::new("detector-score", result.score, weight=0.6),
    EvidenceContribution::new("confidence", result.confidence, weight=0.25),
    EvidenceContribution::new("relative-change", direction_score, weight=0.15),
  ]
  let recommendation = if result.changed {
    "inspect recent deploys and upstream inputs"
  } else {
    "continue monitoring"
  }
  {
    result,
    baseline,
    observed,
    deviation,
    relative_change: relative,
    contributions,
    recommendation: detector + ": " + recommendation,
  }
}

///|
pub fn explanation_strength(explanation : DetectionExplanation) -> Double {
  let mut total = 0.0
  for item in explanation.contributions {
    total += item.contribution
  }
  clamp_probability(total)
}

///|
pub fn strongest_contribution(
  explanation : DetectionExplanation,
) -> EvidenceContribution? {
  if explanation.contributions.length() == 0 {
    return None
  }
  let mut best = explanation.contributions[0]
  for item in explanation.contributions {
    if item.contribution > best.contribution {
      best = item
    }
  }
  Some(best)
}

///|
pub fn explanation_csv_header() -> String {
  "index,changed,score,confidence,baseline,observed,deviation,relative_change,recommendation"
}

///|
pub fn explanation_csv(explanation : DetectionExplanation) -> String {
  "\{explanation.result.index},\{explanation.result.changed},\{explanation.result.score},\{explanation.result.confidence},\{explanation.baseline},\{explanation.observed},\{explanation.deviation},\{explanation.relative_change},\{explanation.recommendation}"
}

///|
pub fn explanation_markdown(explanation : DetectionExplanation) -> String {
  let strongest = match strongest_contribution(explanation) {
    None => "none"
    Some(item) => item.name
  }
  "### Detection explanation\n\n- changed: \{explanation.result.changed}\n- score: \{explanation.result.score}\n- baseline: \{explanation.baseline}\n- observed: \{explanation.observed}\n- strongest evidence: \{strongest}\n- recommendation: \{explanation.recommendation}"
}

///|
pub fn explain_batch(
  results : Array[DetectionResult],
  baseline : Double,
  values : Array[Double],
  detector : String,
) -> Array[DetectionExplanation] {
  let output : Array[DetectionExplanation] = []
  let length = if results.length() < values.length() {
    results.length()
  } else {
    values.length()
  }
  for i in 0..<length {
    output.push(make_explanation(results[i], baseline, values[i], detector))
  }
  output
}

///|
pub fn explanation_alerts(explanations : Array[DetectionExplanation]) -> Int {
  let mut count = 0
  for explanation in explanations {
    if explanation.result.changed {
      count += 1
    }
  }
  count
}
