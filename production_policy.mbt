///|
/// Delivery destination for an operational alert.
pub(all) enum ProductionDeliveryChannel {
  ConsoleChannel
  LogChannel
  TicketChannel
  PagerChannel
  WebhookChannel
  DashboardChannel
}

///|
pub fn production_delivery_channel_name(
  channel : ProductionDeliveryChannel,
) -> String {
  match channel {
    ConsoleChannel => "console"
    LogChannel => "log"
    TicketChannel => "ticket"
    PagerChannel => "pager"
    WebhookChannel => "webhook"
    DashboardChannel => "dashboard"
  }
}

///|
/// A rule deciding whether an event should reach one delivery channel.
pub struct ProductionDeliveryRule {
  name : String
  channel : ProductionDeliveryChannel
  minimum_severity : AlertSeverity
  include_suppressed : Bool
  minimum_score : Double
  cooldown : Int64
}

///|
pub fn ProductionDeliveryRule::new(
  name : String,
  channel : ProductionDeliveryChannel,
  minimum_severity? : AlertSeverity = Warning,
  include_suppressed? : Bool = false,
  minimum_score? : Double = 1.0,
  cooldown? : Int64 = 0L,
) -> ProductionDeliveryRule {
  {
    name,
    channel,
    minimum_severity,
    include_suppressed,
    minimum_score: if minimum_score < 0.0 {
      0.0
    } else {
      minimum_score
    },
    cooldown: if cooldown < 0L {
      0L
    } else {
      cooldown
    },
  }
}

///|
pub fn ProductionDeliveryRule::name(self : ProductionDeliveryRule) -> String {
  self.name
}

///|
pub fn ProductionDeliveryRule::channel(
  self : ProductionDeliveryRule,
) -> ProductionDeliveryChannel {
  self.channel
}

///|
pub fn ProductionDeliveryRule::minimum_severity(
  self : ProductionDeliveryRule,
) -> AlertSeverity {
  self.minimum_severity
}

///|
pub fn ProductionDeliveryRule::include_suppressed(
  self : ProductionDeliveryRule,
) -> Bool {
  self.include_suppressed
}

///|
pub fn ProductionDeliveryRule::minimum_score(
  self : ProductionDeliveryRule,
) -> Double {
  self.minimum_score
}

///|
pub fn ProductionDeliveryRule::cooldown(self : ProductionDeliveryRule) -> Int64 {
  self.cooldown
}

///|
pub fn ProductionDeliveryRule::matches(
  self : ProductionDeliveryRule,
  event : AlertEvent,
) -> Bool {
  production_severity_rank(event.point.severity) >=
  production_severity_rank(self.minimum_severity) &&
  event.point.score >= self.minimum_score &&
  (self.include_suppressed || !event.suppressed)
}

///|
/// The result of evaluating one event against a delivery rule.
pub struct ProductionDeliveryDecision {
  rule : String
  channel : ProductionDeliveryChannel
  allowed : Bool
  reason : String
  fingerprint : String
}

///|
pub fn ProductionDeliveryDecision::rule(
  self : ProductionDeliveryDecision,
) -> String {
  self.rule
}

///|
pub fn ProductionDeliveryDecision::channel(
  self : ProductionDeliveryDecision,
) -> ProductionDeliveryChannel {
  self.channel
}

///|
pub fn ProductionDeliveryDecision::allowed(
  self : ProductionDeliveryDecision,
) -> Bool {
  self.allowed
}

///|
pub fn ProductionDeliveryDecision::reason(
  self : ProductionDeliveryDecision,
) -> String {
  self.reason
}

///|
pub fn ProductionDeliveryDecision::fingerprint(
  self : ProductionDeliveryDecision,
) -> String {
  self.fingerprint
}

///|
pub fn ProductionDeliveryDecision::summary(
  self : ProductionDeliveryDecision,
) -> String {
  self.rule +
  ":" +
  production_delivery_channel_name(self.channel) +
  ",allowed=" +
  self.allowed.to_string() +
  ",reason=" +
  self.reason +
  ",fingerprint=" +
  self.fingerprint
}

///|
/// Stable alert envelope used for deduplication and delivery retries.
pub struct ProductionAlertEnvelope {
  fingerprint : String
  event : AlertEvent
  mut delivery_attempts : Int
  mut delivered : Bool
  mut deduplicated : Int
}

///|
pub fn ProductionAlertEnvelope::new(
  fingerprint : String,
  event : AlertEvent,
) -> ProductionAlertEnvelope {
  {
    fingerprint,
    event,
    delivery_attempts: 0,
    delivered: false,
    deduplicated: 0,
  }
}

///|
pub fn ProductionAlertEnvelope::fingerprint(
  self : ProductionAlertEnvelope,
) -> String {
  self.fingerprint
}

///|
pub fn ProductionAlertEnvelope::event(
  self : ProductionAlertEnvelope,
) -> AlertEvent {
  self.event
}

///|
pub fn ProductionAlertEnvelope::delivery_attempts(
  self : ProductionAlertEnvelope,
) -> Int {
  self.delivery_attempts
}

///|
pub fn ProductionAlertEnvelope::delivered(
  self : ProductionAlertEnvelope,
) -> Bool {
  self.delivered
}

///|
pub fn ProductionAlertEnvelope::deduplicated(
  self : ProductionAlertEnvelope,
) -> Int {
  self.deduplicated
}

///|
pub fn ProductionAlertEnvelope::attempt(self : ProductionAlertEnvelope) -> Unit {
  self.delivery_attempts += 1
}

///|
pub fn ProductionAlertEnvelope::mark_delivered(
  self : ProductionAlertEnvelope,
) -> Unit {
  self.delivered = true
}

///|
pub fn ProductionAlertEnvelope::mark_duplicate(
  self : ProductionAlertEnvelope,
) -> Unit {
  self.deduplicated += 1
}

///|
/// Policy engine combining maintenance, budgets, cooldowns and deduplication.
pub struct ProductionPolicyEngine {
  rules : Array[ProductionDeliveryRule]
  schedule : ProductionSuppressionSchedule
  budget : ProductionEventBudget
  recent : Array[ProductionAlertEnvelope]
  mut evaluated : Int
  mut delivered : Int
  mut suppressed : Int
  mut duplicates : Int
}

///|
pub fn ProductionPolicyEngine::new(
  budget? : ProductionEventBudget = ProductionEventBudget::new(),
) -> ProductionPolicyEngine {
  {
    rules: [],
    schedule: ProductionSuppressionSchedule::new(),
    budget,
    recent: [],
    evaluated: 0,
    delivered: 0,
    suppressed: 0,
    duplicates: 0,
  }
}

///|
pub fn ProductionPolicyEngine::add_rule(
  self : ProductionPolicyEngine,
  rule : ProductionDeliveryRule,
) -> Unit {
  self.rules.push(rule)
}

///|
pub fn ProductionPolicyEngine::add_maintenance(
  self : ProductionPolicyEngine,
  window : ProductionMaintenanceWindow,
) -> Bool {
  self.schedule.add(window)
}

///|
pub fn ProductionPolicyEngine::rules(
  self : ProductionPolicyEngine,
) -> Array[ProductionDeliveryRule] {
  let result : Array[ProductionDeliveryRule] = []
  for rule in self.rules {
    result.push(rule)
  }
  result
}

///|
pub fn ProductionPolicyEngine::evaluated(self : ProductionPolicyEngine) -> Int {
  self.evaluated
}

///|
pub fn ProductionPolicyEngine::delivered(self : ProductionPolicyEngine) -> Int {
  self.delivered
}

///|
pub fn ProductionPolicyEngine::suppressed(self : ProductionPolicyEngine) -> Int {
  self.suppressed
}

///|
pub fn ProductionPolicyEngine::duplicates(self : ProductionPolicyEngine) -> Int {
  self.duplicates
}

///|
fn production_policy_fingerprint(event : AlertEvent, bucket : Int64) -> String {
  let raw = event.metric +
    ":" +
    direction_name(event.point.direction) +
    ":" +
    bucket.to_string()
  let mut checksum = 13
  for character in raw {
    checksum = (checksum * 33 + character.to_int()) % 2147483647
  }
  "alert-" + checksum.to_string()
}

///|
fn ProductionPolicyEngine::find_recent(
  self : ProductionPolicyEngine,
  fingerprint : String,
) -> ProductionAlertEnvelope? {
  for envelope in self.recent {
    if envelope.fingerprint() == fingerprint {
      return Some(envelope)
    }
  }
  None
}

///|
pub fn ProductionPolicyEngine::evaluate(
  self : ProductionPolicyEngine,
  event : AlertEvent,
) -> Array[ProductionDeliveryDecision] {
  self.evaluated += 1
  let bucket = event.point.timestamp / 60L
  let fingerprint = production_policy_fingerprint(event, bucket)
  match self.find_recent(fingerprint) {
    Some(envelope) => {
      envelope.mark_duplicate()
      self.duplicates += 1
    }
    None => self.recent.push(ProductionAlertEnvelope::new(fingerprint, event))
  }
  let in_maintenance = self.schedule.active(event.point.timestamp) is Some(_)
  let budget_allowed = self.budget.allow(event.point.timestamp)
  let result : Array[ProductionDeliveryDecision] = []
  for rule in self.rules {
    let matched = rule.matches(event)
    let allowed = matched && !in_maintenance && budget_allowed
    let reason = if !matched {
      "rule-not-matched"
    } else if in_maintenance {
      "maintenance-window"
    } else if !budget_allowed {
      "budget-exhausted"
    } else {
      self.delivered += 1
      "allowed"
    }
    if !allowed {
      self.suppressed += 1
    }
    result.push({
      rule: rule.name(),
      channel: rule.channel(),
      allowed,
      reason,
      fingerprint,
    })
  }
  while self.recent.length() > 1024 {
    ignore(self.recent.remove(0))
  }
  result
}

///|
pub fn ProductionPolicyEngine::reset(self : ProductionPolicyEngine) -> Unit {
  self.recent.clear()
  self.evaluated = 0
  self.delivered = 0
  self.suppressed = 0
  self.duplicates = 0
}

///|
pub fn production_decisions_markdown(
  decisions : Array[ProductionDeliveryDecision],
) -> String {
  let mut output = "| rule | channel | allowed | reason | fingerprint |\n|---|---|---|---|---|\n"
  for decision in decisions {
    output = output +
      "| " +
      decision.rule() +
      " | " +
      production_delivery_channel_name(decision.channel()) +
      " | " +
      decision.allowed().to_string() +
      " | " +
      decision.reason() +
      " | " +
      decision.fingerprint() +
      " |\n"
  }
  output
}
