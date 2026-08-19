///|
/// Action selected by a production rollout guard.
pub(all) enum ProductionGuardrailAction {
  GuardrailAllow
  GuardrailObserve
  GuardrailWarn
  GuardrailBlock
  GuardrailRollback
}

///|
pub fn production_guardrail_action_name(
  action : ProductionGuardrailAction,
) -> String {
  match action {
    GuardrailAllow => "allow"
    GuardrailObserve => "observe"
    GuardrailWarn => "warn"
    GuardrailBlock => "block"
    GuardrailRollback => "rollback"
  }
}

///|
/// Operational signal monitored during a canary rollout.
pub(all) enum ProductionGuardrailMetricKind {
  GuardrailErrorRate
  GuardrailFalsePositiveRate
  GuardrailDetectionDelay
  GuardrailDataQuality
  GuardrailThroughput
  GuardrailLatency
  GuardrailCoverage
  GuardrailDriftScore
}

///|
pub fn production_guardrail_metric_name(
  metric : ProductionGuardrailMetricKind,
) -> String {
  match metric {
    GuardrailErrorRate => "error-rate"
    GuardrailFalsePositiveRate => "false-positive-rate"
    GuardrailDetectionDelay => "detection-delay"
    GuardrailDataQuality => "data-quality"
    GuardrailThroughput => "throughput"
    GuardrailLatency => "latency"
    GuardrailCoverage => "coverage"
    GuardrailDriftScore => "drift-score"
  }
}

///|
/// Direction of an operational threshold.
pub(all) enum ProductionGuardrailDirection {
  GuardrailAbove
  GuardrailBelow
  GuardrailOutside
}

///|
pub fn production_guardrail_direction_name(
  direction : ProductionGuardrailDirection,
) -> String {
  match direction {
    GuardrailAbove => "above"
    GuardrailBelow => "below"
    GuardrailOutside => "outside"
  }
}

///|
/// A single rollout policy for one service-level signal.
pub struct ProductionGuardrailRule {
  name : String
  metric : ProductionGuardrailMetricKind
  direction : ProductionGuardrailDirection
  warning_threshold : Double
  blocking_threshold : Double
  rollback_threshold : Double
  minimum_samples : Int
  window_size : Int
  consecutive_failures : Int
  recovery_samples : Int
  weight : Double
  enabled : Bool
}

///|
pub fn ProductionGuardrailRule::new(
  name : String,
  metric? : ProductionGuardrailMetricKind = GuardrailErrorRate,
  direction? : ProductionGuardrailDirection = GuardrailAbove,
  warning_threshold? : Double = 0.05,
  blocking_threshold? : Double = 0.10,
  rollback_threshold? : Double = 0.25,
  minimum_samples? : Int = 20,
  window_size? : Int = 100,
  consecutive_failures? : Int = 3,
  recovery_samples? : Int = 5,
  weight? : Double = 1.0,
  enabled? : Bool = true,
) -> ProductionGuardrailRule {
  let warning = if warning_threshold < 0.0 { 0.0 } else { warning_threshold }
  let blocking = if blocking_threshold < warning {
    warning
  } else {
    blocking_threshold
  }
  let rollback = if rollback_threshold < blocking {
    blocking
  } else {
    rollback_threshold
  }
  {
    name,
    metric,
    direction,
    warning_threshold: warning,
    blocking_threshold: blocking,
    rollback_threshold: rollback,
    minimum_samples: if minimum_samples < 1 {
      1
    } else {
      minimum_samples
    },
    window_size: if window_size < 1 {
      1
    } else {
      window_size
    },
    consecutive_failures: if consecutive_failures < 1 {
      1
    } else {
      consecutive_failures
    },
    recovery_samples: if recovery_samples < 1 {
      1
    } else {
      recovery_samples
    },
    weight: if weight < 0.0 {
      0.0
    } else {
      weight
    },
    enabled,
  }
}

///|
pub fn ProductionGuardrailRule::name(self : ProductionGuardrailRule) -> String {
  self.name
}

///|
pub fn ProductionGuardrailRule::metric(
  self : ProductionGuardrailRule,
) -> ProductionGuardrailMetricKind {
  self.metric
}

///|
pub fn ProductionGuardrailRule::direction(
  self : ProductionGuardrailRule,
) -> ProductionGuardrailDirection {
  self.direction
}

///|
pub fn ProductionGuardrailRule::warning_threshold(
  self : ProductionGuardrailRule,
) -> Double {
  self.warning_threshold
}

///|
pub fn ProductionGuardrailRule::blocking_threshold(
  self : ProductionGuardrailRule,
) -> Double {
  self.blocking_threshold
}

///|
pub fn ProductionGuardrailRule::rollback_threshold(
  self : ProductionGuardrailRule,
) -> Double {
  self.rollback_threshold
}

///|
pub fn ProductionGuardrailRule::minimum_samples(
  self : ProductionGuardrailRule,
) -> Int {
  self.minimum_samples
}

///|
pub fn ProductionGuardrailRule::window_size(
  self : ProductionGuardrailRule,
) -> Int {
  self.window_size
}

///|
pub fn ProductionGuardrailRule::consecutive_failures(
  self : ProductionGuardrailRule,
) -> Int {
  self.consecutive_failures
}

///|
pub fn ProductionGuardrailRule::recovery_samples(
  self : ProductionGuardrailRule,
) -> Int {
  self.recovery_samples
}

///|
pub fn ProductionGuardrailRule::weight(
  self : ProductionGuardrailRule,
) -> Double {
  self.weight
}

///|
pub fn ProductionGuardrailRule::enabled(self : ProductionGuardrailRule) -> Bool {
  self.enabled
}

///|
pub fn ProductionGuardrailRule::with_enabled(
  self : ProductionGuardrailRule,
  enabled : Bool,
) -> ProductionGuardrailRule {
  {
    name: self.name,
    metric: self.metric,
    direction: self.direction,
    warning_threshold: self.warning_threshold,
    blocking_threshold: self.blocking_threshold,
    rollback_threshold: self.rollback_threshold,
    minimum_samples: self.minimum_samples,
    window_size: self.window_size,
    consecutive_failures: self.consecutive_failures,
    recovery_samples: self.recovery_samples,
    weight: self.weight,
    enabled,
  }
}

///|
/// Observed value supplied to a rollout guard.
pub struct ProductionGuardrailObservation {
  timestamp : Int64
  metric : ProductionGuardrailMetricKind
  value : Double
  baseline : Double
  sample_count : Int
  confidence : Double
  source : String
}

///|
pub fn ProductionGuardrailObservation::new(
  timestamp : Int64,
  metric : ProductionGuardrailMetricKind,
  value : Double,
  sample_count? : Int = 0,
  baseline? : Double = 0.0,
  confidence? : Double = 1.0,
  source? : String = "runtime",
) -> ProductionGuardrailObservation {
  {
    timestamp,
    metric,
    value,
    baseline,
    sample_count: if sample_count < 0 {
      0
    } else {
      sample_count
    },
    confidence: clamp_probability(confidence),
    source,
  }
}

///|
pub fn ProductionGuardrailObservation::timestamp(
  self : ProductionGuardrailObservation,
) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionGuardrailObservation::metric(
  self : ProductionGuardrailObservation,
) -> ProductionGuardrailMetricKind {
  self.metric
}

///|
pub fn ProductionGuardrailObservation::value(
  self : ProductionGuardrailObservation,
) -> Double {
  self.value
}

///|
pub fn ProductionGuardrailObservation::baseline(
  self : ProductionGuardrailObservation,
) -> Double {
  self.baseline
}

///|
pub fn ProductionGuardrailObservation::sample_count(
  self : ProductionGuardrailObservation,
) -> Int {
  self.sample_count
}

///|
pub fn ProductionGuardrailObservation::confidence(
  self : ProductionGuardrailObservation,
) -> Double {
  self.confidence
}

///|
pub fn ProductionGuardrailObservation::source(
  self : ProductionGuardrailObservation,
) -> String {
  self.source
}

///|
pub fn ProductionGuardrailObservation::relative_change(
  self : ProductionGuardrailObservation,
) -> Double {
  if self.baseline == 0.0 {
    if self.value == 0.0 {
      0.0
    } else {
      self.value
    }
  } else {
    (self.value - self.baseline) / self.baseline
  }
}

///|
pub fn ProductionGuardrailObservation::is_finite(
  self : ProductionGuardrailObservation,
) -> Bool {
  self.value == self.value && self.value > -1.0e308 && self.value < 1.0e308
}

///|
/// Decision emitted by a guard after evaluating an observation.
pub struct ProductionGuardrailDecision {
  action : ProductionGuardrailAction
  rule_name : String
  metric : ProductionGuardrailMetricKind
  value : Double
  threshold : Double
  score : Double
  triggered : Bool
  failure_streak : Int
  recovery_streak : Int
  sequence : Int64
  reason : String
}

///|
pub fn ProductionGuardrailDecision::action(
  self : ProductionGuardrailDecision,
) -> ProductionGuardrailAction {
  self.action
}

///|
pub fn ProductionGuardrailDecision::rule_name(
  self : ProductionGuardrailDecision,
) -> String {
  self.rule_name
}

///|
pub fn ProductionGuardrailDecision::metric(
  self : ProductionGuardrailDecision,
) -> ProductionGuardrailMetricKind {
  self.metric
}

///|
pub fn ProductionGuardrailDecision::value(
  self : ProductionGuardrailDecision,
) -> Double {
  self.value
}

///|
pub fn ProductionGuardrailDecision::threshold(
  self : ProductionGuardrailDecision,
) -> Double {
  self.threshold
}

///|
pub fn ProductionGuardrailDecision::score(
  self : ProductionGuardrailDecision,
) -> Double {
  self.score
}

///|
pub fn ProductionGuardrailDecision::triggered(
  self : ProductionGuardrailDecision,
) -> Bool {
  self.triggered
}

///|
pub fn ProductionGuardrailDecision::failure_streak(
  self : ProductionGuardrailDecision,
) -> Int {
  self.failure_streak
}

///|
pub fn ProductionGuardrailDecision::recovery_streak(
  self : ProductionGuardrailDecision,
) -> Int {
  self.recovery_streak
}

///|
pub fn ProductionGuardrailDecision::sequence(
  self : ProductionGuardrailDecision,
) -> Int64 {
  self.sequence
}

///|
pub fn ProductionGuardrailDecision::reason(
  self : ProductionGuardrailDecision,
) -> String {
  self.reason
}

///|
pub fn ProductionGuardrailDecision::summary(
  self : ProductionGuardrailDecision,
) -> String {
  production_guardrail_action_name(self.action) +
  ":" +
  self.rule_name +
  " value=" +
  self.value.to_string() +
  " score=" +
  self.score.to_string() +
  " " +
  self.reason
}

///|
fn production_guardrail_compare(
  direction : ProductionGuardrailDirection,
  value : Double,
  threshold : Double,
) -> Bool {
  match direction {
    GuardrailAbove => value >= threshold
    GuardrailBelow => value <= threshold
    GuardrailOutside => value >= threshold || value <= -threshold
  }
}

///|
fn production_guardrail_distance(
  direction : ProductionGuardrailDirection,
  value : Double,
  threshold : Double,
) -> Double {
  match direction {
    GuardrailAbove => value - threshold
    GuardrailBelow => threshold - value
    GuardrailOutside => {
      let above = value - threshold
      let below = -threshold - value
      if above > below {
        above
      } else {
        below
      }
    }
  }
}

///|
fn production_guardrail_score(
  rule : ProductionGuardrailRule,
  value : Double,
) -> Double {
  if production_guardrail_compare(
      rule.direction(),
      value,
      rule.warning_threshold(),
    ) {
    let distance = production_guardrail_distance(
      rule.direction(),
      value,
      rule.warning_threshold(),
    )
    let span = rule.rollback_threshold() - rule.warning_threshold()
    if span <= 0.0 {
      rule.weight()
    } else {
      rule.weight() * (1.0 + distance / span)
    }
  } else {
    0.0
  }
}

///|
fn production_guardrail_find_rule(
  rules : Array[ProductionGuardrailRule],
  metric : ProductionGuardrailMetricKind,
) -> Int {
  for i = 0; i < rules.length(); i = i + 1 {
    if production_guardrail_metric_matches(rules[i].metric(), metric) &&
      rules[i].enabled() {
      return i
    }
  }
  -1
}

///|
fn production_guardrail_metric_matches(
  left : ProductionGuardrailMetricKind,
  right : ProductionGuardrailMetricKind,
) -> Bool {
  match left {
    GuardrailErrorRate => right is GuardrailErrorRate
    GuardrailFalsePositiveRate => right is GuardrailFalsePositiveRate
    GuardrailDetectionDelay => right is GuardrailDetectionDelay
    GuardrailDataQuality => right is GuardrailDataQuality
    GuardrailThroughput => right is GuardrailThroughput
    GuardrailLatency => right is GuardrailLatency
    GuardrailCoverage => right is GuardrailCoverage
    GuardrailDriftScore => right is GuardrailDriftScore
  }
}

///|
/// Stateful canary and rollout gate.
pub struct ProductionGuardrailController {
  mut rules : Array[ProductionGuardrailRule]
  mut history : Array[ProductionGuardrailDecision]
  mut failure_streak : Int
  mut recovery_streak : Int
  mut sequence : Int64
  mut blocked : Bool
  mut paused : Bool
  mut last_timestamp : Int64
  mut evaluated : Int
  mut triggered : Int
}

///|
pub fn ProductionGuardrailController::new() -> ProductionGuardrailController {
  {
    rules: [],
    history: [],
    failure_streak: 0,
    recovery_streak: 0,
    sequence: 0L,
    blocked: false,
    paused: false,
    last_timestamp: 0L,
    evaluated: 0,
    triggered: 0,
  }
}

///|
pub fn ProductionGuardrailController::register(
  self : ProductionGuardrailController,
  rule : ProductionGuardrailRule,
) -> Bool {
  for i = 0; i < self.rules.length(); i = i + 1 {
    if self.rules[i].name() == rule.name() {
      self.rules[i] = rule
      return false
    }
  }
  self.rules.push(rule)
  true
}

///|
pub fn ProductionGuardrailController::remove(
  self : ProductionGuardrailController,
  name : String,
) -> Bool {
  let mut found = false
  let remaining : Array[ProductionGuardrailRule] = []
  for rule in self.rules {
    if rule.name() == name {
      found = true
    } else {
      remaining.push(rule)
    }
  }
  if found {
    self.rules = remaining
  }
  found
}

///|
pub fn ProductionGuardrailController::rule_count(
  self : ProductionGuardrailController,
) -> Int {
  self.rules.length()
}

///|
pub fn ProductionGuardrailController::rules(
  self : ProductionGuardrailController,
) -> Array[ProductionGuardrailRule] {
  self.rules[:].to_owned()
}

///|
pub fn ProductionGuardrailController::history(
  self : ProductionGuardrailController,
) -> Array[ProductionGuardrailDecision] {
  self.history[:].to_owned()
}

///|
pub fn ProductionGuardrailController::is_blocked(
  self : ProductionGuardrailController,
) -> Bool {
  self.blocked
}

///|
pub fn ProductionGuardrailController::is_paused(
  self : ProductionGuardrailController,
) -> Bool {
  self.paused
}

///|
pub fn ProductionGuardrailController::failure_streak(
  self : ProductionGuardrailController,
) -> Int {
  self.failure_streak
}

///|
pub fn ProductionGuardrailController::recovery_streak(
  self : ProductionGuardrailController,
) -> Int {
  self.recovery_streak
}

///|
pub fn ProductionGuardrailController::evaluated(
  self : ProductionGuardrailController,
) -> Int {
  self.evaluated
}

///|
pub fn ProductionGuardrailController::triggered(
  self : ProductionGuardrailController,
) -> Int {
  self.triggered
}

///|
pub fn ProductionGuardrailController::pause(
  self : ProductionGuardrailController,
) -> Unit {
  self.paused = true
}

///|
pub fn ProductionGuardrailController::resume_guardrail(
  self : ProductionGuardrailController,
) -> Unit {
  self.paused = false
}

///|
pub fn ProductionGuardrailController::unblock(
  self : ProductionGuardrailController,
) -> Unit {
  self.blocked = false
  self.failure_streak = 0
  self.recovery_streak = 0
}

///|
fn production_guardrail_make_decision(
  rule : ProductionGuardrailRule,
  observation : ProductionGuardrailObservation,
  action : ProductionGuardrailAction,
  score : Double,
  failure_streak : Int,
  recovery_streak : Int,
  sequence : Int64,
  reason : String,
) -> ProductionGuardrailDecision {
  let threshold = match action {
    GuardrailAllow => rule.warning_threshold()
    GuardrailObserve => rule.warning_threshold()
    GuardrailWarn => rule.warning_threshold()
    GuardrailBlock => rule.blocking_threshold()
    GuardrailRollback => rule.rollback_threshold()
  }
  {
    action,
    rule_name: rule.name(),
    metric: observation.metric(),
    value: observation.value(),
    threshold,
    score,
    triggered: action is GuardrailWarn ||
    action is GuardrailBlock ||
    action is GuardrailRollback,
    failure_streak,
    recovery_streak,
    sequence,
    reason,
  }
}

///|
fn production_guardrail_invalid_decision(
  observation : ProductionGuardrailObservation,
  sequence : Int64,
) -> ProductionGuardrailDecision {
  {
    action: GuardrailBlock,
    rule_name: "input-validation",
    metric: observation.metric(),
    value: observation.value(),
    threshold: 0.0,
    score: 1.0,
    triggered: true,
    failure_streak: 1,
    recovery_streak: 0,
    sequence,
    reason: "observation is non-finite",
  }
}

///|
/// Evaluate one signal and update the controller state.
pub fn ProductionGuardrailController::evaluate(
  self : ProductionGuardrailController,
  observation : ProductionGuardrailObservation,
) -> ProductionGuardrailDecision {
  self.sequence = self.sequence + 1L
  self.evaluated = self.evaluated + 1
  self.last_timestamp = observation.timestamp()
  let invalid = !observation.is_finite()
  if invalid {
    self.failure_streak = self.failure_streak + 1
    self.recovery_streak = 0
    self.blocked = true
    let decision = production_guardrail_invalid_decision(
      observation,
      self.sequence,
    )
    self.history.push(decision)
    self.triggered = self.triggered + 1
    return decision
  }
  let rule_index = production_guardrail_find_rule(
    self.rules,
    observation.metric(),
  )
  if rule_index < 0 {
    let decision = {
      action: if self.paused {
        GuardrailObserve
      } else {
        GuardrailAllow
      },
      rule_name: "unconfigured",
      metric: observation.metric(),
      value: observation.value(),
      threshold: 0.0,
      score: 0.0,
      triggered: false,
      failure_streak: self.failure_streak,
      recovery_streak: self.recovery_streak,
      sequence: self.sequence,
      reason: "no enabled rule for metric",
    }
    self.history.push(decision)
    return decision
  }
  let rule = self.rules[rule_index]
  if observation.sample_count() < rule.minimum_samples() {
    let decision = production_guardrail_make_decision(
      rule,
      observation,
      GuardrailObserve,
      0.0,
      self.failure_streak,
      self.recovery_streak,
      self.sequence,
      "sample count is below the minimum",
    )
    self.history.push(decision)
    return decision
  }
  let score = production_guardrail_score(rule, observation.value())
  let rollback = production_guardrail_compare(
    rule.direction(),
    observation.value(),
    rule.rollback_threshold(),
  )
  let block = production_guardrail_compare(
    rule.direction(),
    observation.value(),
    rule.blocking_threshold(),
  )
  let warning = production_guardrail_compare(
    rule.direction(),
    observation.value(),
    rule.warning_threshold(),
  )
  let action = if rollback {
    self.failure_streak = self.failure_streak + 1
    self.recovery_streak = 0
    if self.failure_streak >= rule.consecutive_failures() {
      self.blocked = true
      GuardrailRollback
    } else {
      GuardrailBlock
    }
  } else if block {
    self.failure_streak = self.failure_streak + 1
    self.recovery_streak = 0
    if self.failure_streak >= rule.consecutive_failures() {
      self.blocked = true
      GuardrailBlock
    } else {
      GuardrailWarn
    }
  } else if warning {
    self.failure_streak = self.failure_streak + 1
    self.recovery_streak = 0
    GuardrailWarn
  } else {
    self.failure_streak = 0
    self.recovery_streak = self.recovery_streak + 1
    if self.blocked && self.recovery_streak >= rule.recovery_samples() {
      self.blocked = false
    }
    if self.paused {
      GuardrailObserve
    } else {
      GuardrailAllow
    }
  }
  let reason = match action {
    GuardrailAllow => "signal is within rollout limits"
    GuardrailObserve => "rollout is paused or input is warming up"
    GuardrailWarn => "signal crossed the warning limit"
    GuardrailBlock => "signal crossed the blocking limit"
    GuardrailRollback => "signal crossed the rollback limit"
  }
  let decision = production_guardrail_make_decision(
    rule,
    observation,
    action,
    score,
    self.failure_streak,
    self.recovery_streak,
    self.sequence,
    reason,
  )
  self.history.push(decision)
  if decision.triggered() {
    self.triggered = self.triggered + 1
  }
  decision
}

///|
/// Evaluate aligned observations and return one decision per signal.
pub fn ProductionGuardrailController::evaluate_batch(
  self : ProductionGuardrailController,
  observations : Array[ProductionGuardrailObservation],
) -> Array[ProductionGuardrailDecision] {
  let decisions : Array[ProductionGuardrailDecision] = []
  for observation in observations {
    decisions.push(self.evaluate(observation))
  }
  decisions
}

///|
pub fn ProductionGuardrailController::latest(
  self : ProductionGuardrailController,
) -> ProductionGuardrailDecision? {
  if self.history.length() == 0 {
    None
  } else {
    Some(self.history[self.history.length() - 1])
  }
}

///|
pub fn ProductionGuardrailController::clear_history(
  self : ProductionGuardrailController,
) -> Unit {
  self.history = []
}

///|
/// Compact rollout health summary.
pub struct ProductionGuardrailSummary {
  evaluated : Int
  triggered : Int
  blocked : Bool
  paused : Bool
  failure_streak : Int
  recovery_streak : Int
  risk_score : Double
}

///|
pub fn ProductionGuardrailSummary::evaluated(
  self : ProductionGuardrailSummary,
) -> Int {
  self.evaluated
}

///|
pub fn ProductionGuardrailSummary::triggered(
  self : ProductionGuardrailSummary,
) -> Int {
  self.triggered
}

///|
pub fn ProductionGuardrailSummary::blocked(
  self : ProductionGuardrailSummary,
) -> Bool {
  self.blocked
}

///|
pub fn ProductionGuardrailSummary::paused(
  self : ProductionGuardrailSummary,
) -> Bool {
  self.paused
}

///|
pub fn ProductionGuardrailSummary::failure_streak(
  self : ProductionGuardrailSummary,
) -> Int {
  self.failure_streak
}

///|
pub fn ProductionGuardrailSummary::recovery_streak(
  self : ProductionGuardrailSummary,
) -> Int {
  self.recovery_streak
}

///|
pub fn ProductionGuardrailSummary::risk_score(
  self : ProductionGuardrailSummary,
) -> Double {
  self.risk_score
}

///|
pub fn ProductionGuardrailController::summary(
  self : ProductionGuardrailController,
) -> ProductionGuardrailSummary {
  let mut score = 0.0
  let start = if self.history.length() > 20 {
    self.history.length() - 20
  } else {
    0
  }
  for i = start; i < self.history.length(); i = i + 1 {
    score = score + self.history[i].score()
  }
  let denominator = if self.history.length() - start == 0 {
    1.0
  } else {
    (self.history.length() - start).to_double()
  }
  {
    evaluated: self.evaluated,
    triggered: self.triggered,
    blocked: self.blocked,
    paused: self.paused,
    failure_streak: self.failure_streak,
    recovery_streak: self.recovery_streak,
    risk_score: score / denominator,
  }
}

///|
/// A named canary stage with an explicit exposure range.
pub struct ProductionRolloutStage {
  name : String
  exposure : Double
  minimum_duration : Int64
  maximum_duration : Int64
  required_health : Double
  automatic_promotion : Bool
}

///|
pub fn ProductionRolloutStage::new(
  name : String,
  exposure? : Double = 0.1,
  minimum_duration? : Int64 = 300L,
  maximum_duration? : Int64 = 3600L,
  required_health? : Double = 0.99,
  automatic_promotion? : Bool = false,
) -> ProductionRolloutStage {
  let min_duration = if minimum_duration < 0L { 0L } else { minimum_duration }
  {
    name,
    exposure: clamp_probability(exposure),
    minimum_duration: min_duration,
    maximum_duration: if maximum_duration < min_duration {
      min_duration
    } else {
      maximum_duration
    },
    required_health: clamp_probability(required_health),
    automatic_promotion,
  }
}

///|
pub fn ProductionRolloutStage::name(self : ProductionRolloutStage) -> String {
  self.name
}

///|
pub fn ProductionRolloutStage::exposure(
  self : ProductionRolloutStage,
) -> Double {
  self.exposure
}

///|
pub fn ProductionRolloutStage::minimum_duration(
  self : ProductionRolloutStage,
) -> Int64 {
  self.minimum_duration
}

///|
pub fn ProductionRolloutStage::maximum_duration(
  self : ProductionRolloutStage,
) -> Int64 {
  self.maximum_duration
}

///|
pub fn ProductionRolloutStage::required_health(
  self : ProductionRolloutStage,
) -> Double {
  self.required_health
}

///|
pub fn ProductionRolloutStage::automatic_promotion(
  self : ProductionRolloutStage,
) -> Bool {
  self.automatic_promotion
}

///|
/// Ordered rollout plan used by deployment orchestration.
pub struct ProductionRolloutPlan {
  name : String
  stages : Array[ProductionRolloutStage]
  mut active_stage : Int
  mut started_at : Int64
  mut completed : Bool
  mut aborted : Bool
}

///|
pub fn ProductionRolloutPlan::new(name : String) -> ProductionRolloutPlan {
  {
    name,
    stages: [],
    active_stage: 0,
    started_at: 0L,
    completed: false,
    aborted: false,
  }
}

///|
pub fn ProductionRolloutPlan::name(self : ProductionRolloutPlan) -> String {
  self.name
}

///|
pub fn ProductionRolloutPlan::add_stage(
  self : ProductionRolloutPlan,
  stage : ProductionRolloutStage,
) -> Unit {
  if !self.completed && !self.aborted {
    self.stages.push(stage)
  }
}

///|
pub fn ProductionRolloutPlan::stage_count(self : ProductionRolloutPlan) -> Int {
  self.stages.length()
}

///|
pub fn ProductionRolloutPlan::stages(
  self : ProductionRolloutPlan,
) -> Array[ProductionRolloutStage] {
  self.stages[:].to_owned()
}

///|
pub fn ProductionRolloutPlan::active_stage(self : ProductionRolloutPlan) -> Int {
  self.active_stage
}

///|
pub fn ProductionRolloutPlan::current_stage(
  self : ProductionRolloutPlan,
) -> ProductionRolloutStage? {
  if self.stages.length() == 0 || self.active_stage >= self.stages.length() {
    None
  } else {
    Some(self.stages[self.active_stage])
  }
}

///|
pub fn ProductionRolloutPlan::start(
  self : ProductionRolloutPlan,
  timestamp : Int64,
) -> Bool {
  if self.stages.length() == 0 || self.completed || self.aborted {
    false
  } else {
    self.started_at = timestamp
    self.active_stage = 0
    true
  }
}

///|
pub fn ProductionRolloutPlan::started_at(self : ProductionRolloutPlan) -> Int64 {
  self.started_at
}

///|
pub fn ProductionRolloutPlan::is_completed(
  self : ProductionRolloutPlan,
) -> Bool {
  self.completed
}

///|
pub fn ProductionRolloutPlan::is_aborted(self : ProductionRolloutPlan) -> Bool {
  self.aborted
}

///|
pub fn ProductionRolloutPlan::promote(
  self : ProductionRolloutPlan,
  timestamp : Int64,
  health : Double,
) -> Bool {
  if self.completed || self.aborted || self.stages.length() == 0 {
    false
  } else {
    let stage = self.stages[self.active_stage]
    let elapsed = timestamp - self.started_at
    if elapsed < stage.minimum_duration() || health < stage.required_health() {
      false
    } else if self.active_stage + 1 >= self.stages.length() {
      self.completed = true
      true
    } else {
      self.active_stage = self.active_stage + 1
      self.started_at = timestamp
      true
    }
  }
}

///|
pub fn ProductionRolloutPlan::abort(self : ProductionRolloutPlan) -> Unit {
  if !self.completed {
    self.aborted = true
  }
}

///|
/// Validate a plan before it is handed to a deployment service.
pub fn ProductionRolloutPlan::validate(
  self : ProductionRolloutPlan,
) -> Array[String] {
  let issues : Array[String] = []
  if self.name.length() == 0 {
    issues.push("rollout name is empty")
  }
  if self.stages.length() == 0 {
    issues.push("rollout has no stages")
  }
  for i = 0; i < self.stages.length(); i = i + 1 {
    let stage = self.stages[i]
    if stage.name().length() == 0 {
      issues.push("stage " + i.to_string() + " has no name")
    }
    if i > 0 {
      let previous = self.stages[i - 1]
      if stage.exposure() < previous.exposure() {
        issues.push("stage exposure decreases at " + i.to_string())
      }
    }
    if stage.minimum_duration() > stage.maximum_duration() {
      issues.push("stage duration bounds are invalid at " + i.to_string())
    }
  }
  issues
}

///|
/// Stable text representation for deployment audit logs.
pub fn ProductionRolloutPlan::describe(self : ProductionRolloutPlan) -> String {
  let pieces : Array[String] = []
  let completed_text = if self.completed { "true" } else { "false" }
  let aborted_text = if self.aborted { "true" } else { "false" }
  pieces.push("plan=" + self.name)
  pieces.push("active=" + self.active_stage.to_string())
  pieces.push("completed=" + completed_text)
  pieces.push("aborted=" + aborted_text)
  for i = 0; i < self.stages.length(); i = i + 1 {
    let stage = self.stages[i]
    pieces.push(
      "stage" +
      i.to_string() +
      "=" +
      stage.name() +
      "@" +
      stage.exposure().to_string(),
    )
  }
  pieces.join(" ")
}

///|
/// Bounded canary tracker that joins guard decisions with rollout stages.
pub struct ProductionCanaryTracker {
  plan : ProductionRolloutPlan
  guardrail : ProductionGuardrailController
  mut observations : Int
  mut healthy_observations : Int
  mut blocked_observations : Int
  mut last_decision : ProductionGuardrailDecision?
}

///|
pub fn ProductionCanaryTracker::new(
  plan : ProductionRolloutPlan,
  guardrail : ProductionGuardrailController,
) -> ProductionCanaryTracker {
  {
    plan,
    guardrail,
    observations: 0,
    healthy_observations: 0,
    blocked_observations: 0,
    last_decision: None,
  }
}

///|
pub fn ProductionCanaryTracker::plan(
  self : ProductionCanaryTracker,
) -> ProductionRolloutPlan {
  self.plan
}

///|
pub fn ProductionCanaryTracker::guardrail(
  self : ProductionCanaryTracker,
) -> ProductionGuardrailController {
  self.guardrail
}

///|
pub fn ProductionCanaryTracker::observations(
  self : ProductionCanaryTracker,
) -> Int {
  self.observations
}

///|
pub fn ProductionCanaryTracker::healthy_observations(
  self : ProductionCanaryTracker,
) -> Int {
  self.healthy_observations
}

///|
pub fn ProductionCanaryTracker::blocked_observations(
  self : ProductionCanaryTracker,
) -> Int {
  self.blocked_observations
}

///|
pub fn ProductionCanaryTracker::health(
  self : ProductionCanaryTracker,
) -> Double {
  if self.observations == 0 {
    1.0
  } else {
    self.healthy_observations.to_double() / self.observations.to_double()
  }
}

///|
pub fn ProductionCanaryTracker::observe(
  self : ProductionCanaryTracker,
  observation : ProductionGuardrailObservation,
) -> ProductionGuardrailDecision {
  let decision = self.guardrail.evaluate(observation)
  self.observations = self.observations + 1
  self.last_decision = Some(decision)
  if decision.action() is GuardrailAllow ||
    decision.action() is GuardrailObserve {
    self.healthy_observations = self.healthy_observations + 1
  }
  if decision.action() is GuardrailBlock ||
    decision.action() is GuardrailRollback {
    self.blocked_observations = self.blocked_observations + 1
  }
  decision
}

///|
pub fn ProductionCanaryTracker::try_promote(
  self : ProductionCanaryTracker,
  timestamp : Int64,
) -> Bool {
  self.plan.promote(timestamp, self.health())
}

///|
pub fn ProductionCanaryTracker::last_decision(
  self : ProductionCanaryTracker,
) -> ProductionGuardrailDecision? {
  self.last_decision
}

///|
pub fn ProductionCanaryTracker::reset(self : ProductionCanaryTracker) -> Unit {
  self.observations = 0
  self.healthy_observations = 0
  self.blocked_observations = 0
  self.last_decision = None
  self.guardrail.clear_history()
}

///|
pub fn production_guardrail_action_is_failure(
  action : ProductionGuardrailAction,
) -> Bool {
  action is GuardrailBlock || action is GuardrailRollback
}

///|
pub fn production_guardrail_action_is_terminal(
  action : ProductionGuardrailAction,
) -> Bool {
  action is GuardrailRollback
}

///|
pub fn production_guardrail_health_from_actions(
  actions : Array[ProductionGuardrailAction],
) -> Double {
  if actions.length() == 0 {
    1.0
  } else {
    let mut healthy = 0
    for action in actions {
      if !production_guardrail_action_is_failure(action) {
        healthy = healthy + 1
      }
    }
    healthy.to_double() / actions.length().to_double()
  }
}

///|
pub fn production_guardrail_decisions_json(
  decisions : Array[ProductionGuardrailDecision],
) -> String {
  let entries : Array[String] = []
  for decision in decisions {
    entries.push(
      "{\"action\":\"" +
      production_guardrail_action_name(decision.action()) +
      "\",\"metric\":\"" +
      production_guardrail_metric_name(decision.metric()) +
      "\",\"value\":" +
      decision.value().to_string() +
      ",\"score\":" +
      decision.score().to_string() +
      "}",
    )
  }
  "[" + entries.join(",") + "]"
}
