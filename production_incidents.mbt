///|
/// Lifecycle of a grouped production incident.
pub(all) enum ProductionIncidentState {
  OpenIncident
  AcknowledgedIncident
  SnoozedIncident
  ResolvedIncident
  ReopenedIncident
}

///|
pub fn production_incident_state_name(
  state : ProductionIncidentState,
) -> String {
  match state {
    OpenIncident => "open"
    AcknowledgedIncident => "acknowledged"
    SnoozedIncident => "snoozed"
    ResolvedIncident => "resolved"
    ReopenedIncident => "reopened"
  }
}

///|
/// A grouped set of related monitor events for one metric.
pub struct ProductionIncident {
  id : Int
  metric : String
  first_timestamp : Int64
  mut last_timestamp : Int64
  mut alert_count : Int
  mut max_score : Double
  mut severity : AlertSeverity
  mut state : ProductionIncidentState
  mut acknowledged : Bool
  mut snooze_until : Int64?
  mut escalation_level : Int
  mut recovery_observations : Int
}

///|
pub fn ProductionIncident::new(
  id : Int,
  event : ProductionMonitorEvent,
) -> ProductionIncident {
  {
    id,
    metric: event.metric(),
    first_timestamp: event.timestamp(),
    last_timestamp: event.timestamp(),
    alert_count: 1,
    max_score: event.result().score,
    severity: severity_from_score(event.result().score),
    state: OpenIncident,
    acknowledged: false,
    snooze_until: None,
    escalation_level: 0,
    recovery_observations: 0,
  }
}

///|
pub fn ProductionIncident::id(self : ProductionIncident) -> Int {
  self.id
}

///|
pub fn ProductionIncident::metric(self : ProductionIncident) -> String {
  self.metric
}

///|
pub fn ProductionIncident::first_timestamp(self : ProductionIncident) -> Int64 {
  self.first_timestamp
}

///|
pub fn ProductionIncident::last_timestamp(self : ProductionIncident) -> Int64 {
  self.last_timestamp
}

///|
pub fn ProductionIncident::alert_count(self : ProductionIncident) -> Int {
  self.alert_count
}

///|
pub fn ProductionIncident::max_score(self : ProductionIncident) -> Double {
  self.max_score
}

///|
pub fn ProductionIncident::severity(self : ProductionIncident) -> AlertSeverity {
  self.severity
}

///|
pub fn ProductionIncident::state(
  self : ProductionIncident,
) -> ProductionIncidentState {
  self.state
}

///|
pub fn ProductionIncident::acknowledged(self : ProductionIncident) -> Bool {
  self.acknowledged
}

///|
pub fn ProductionIncident::escalation_level(self : ProductionIncident) -> Int {
  self.escalation_level
}

///|
pub fn ProductionIncident::is_open(self : ProductionIncident) -> Bool {
  !production_incident_state_is(self.state, ResolvedIncident)
}

///|
pub fn ProductionIncident::duration(self : ProductionIncident) -> Int64 {
  self.last_timestamp - self.first_timestamp
}

///|
pub fn ProductionIncident::absorb(
  self : ProductionIncident,
  event : ProductionMonitorEvent,
) -> Bool {
  if event.metric() != self.metric || !self.is_open() {
    return false
  }
  self.last_timestamp = event.timestamp()
  self.alert_count += 1
  if event.result().score > self.max_score {
    self.max_score = event.result().score
    self.severity = severity_from_score(self.max_score)
  }
  self.recovery_observations = 0
  if production_incident_state_is(self.state, SnoozedIncident) {
    match self.snooze_until {
      Some(until) => if event.timestamp() >= until { self.state = OpenIncident }
      None => self.state = OpenIncident
    }
  }
  true
}

///|
pub fn ProductionIncident::acknowledge(self : ProductionIncident) -> Unit {
  self.acknowledged = true
  self.state = AcknowledgedIncident
}

///|
pub fn ProductionIncident::snooze(
  self : ProductionIncident,
  until : Int64,
) -> Unit {
  self.snooze_until = Some(until)
  self.state = SnoozedIncident
}

///|
pub fn ProductionIncident::observe_recovery(self : ProductionIncident) -> Unit {
  self.recovery_observations += 1
}

///|
pub fn ProductionIncident::recovery_observations(
  self : ProductionIncident,
) -> Int {
  self.recovery_observations
}

///|
pub fn ProductionIncident::resolve(self : ProductionIncident) -> Unit {
  self.state = ResolvedIncident
  self.snooze_until = None
}

///|
pub fn ProductionIncident::reopen(self : ProductionIncident) -> Unit {
  self.state = ReopenedIncident
  self.recovery_observations = 0
}

///|
pub fn ProductionIncident::escalate(self : ProductionIncident) -> Int {
  self.escalation_level += 1
  self.escalation_level
}

///|
pub fn ProductionIncident::summary(self : ProductionIncident) -> String {
  "incident=" +
  self.id.to_string() +
  ",metric=" +
  self.metric +
  ",state=" +
  production_incident_state_name(self.state) +
  ",severity=" +
  severity_name(self.severity) +
  ",alerts=" +
  self.alert_count.to_string() +
  ",max_score=" +
  self.max_score.to_string() +
  ",duration=" +
  self.duration().to_string()
}

///|
/// Controls incident grouping, recovery and retention.
pub struct ProductionIncidentPolicy {
  grouping_gap : Int64
  recovery_points : Int
  escalation_after : Int
  retention : Int
}

///|
pub fn ProductionIncidentPolicy::new(
  grouping_gap? : Int64 = 300L,
  recovery_points? : Int = 3,
  escalation_after? : Int = 5,
  retention? : Int = 512,
) -> ProductionIncidentPolicy {
  {
    grouping_gap: if grouping_gap < 0L {
      0L
    } else {
      grouping_gap
    },
    recovery_points: if recovery_points < 1 {
      1
    } else {
      recovery_points
    },
    escalation_after: if escalation_after < 1 {
      1
    } else {
      escalation_after
    },
    retention: if retention < 1 {
      1
    } else {
      retention
    },
  }
}

///|
pub fn ProductionIncidentPolicy::grouping_gap(
  self : ProductionIncidentPolicy,
) -> Int64 {
  self.grouping_gap
}

///|
pub fn ProductionIncidentPolicy::recovery_points(
  self : ProductionIncidentPolicy,
) -> Int {
  self.recovery_points
}

///|
pub fn ProductionIncidentPolicy::escalation_after(
  self : ProductionIncidentPolicy,
) -> Int {
  self.escalation_after
}

///|
pub fn ProductionIncidentPolicy::retention(
  self : ProductionIncidentPolicy,
) -> Int {
  self.retention
}

///|
/// Incident manager used by streaming and batch integrations.
pub struct ProductionIncidentManager {
  policy : ProductionIncidentPolicy
  incidents : Array[ProductionIncident]
  mut next_id : Int
  mut ingested : Int
  mut grouped : Int
  mut resolved : Int
}

///|
pub fn ProductionIncidentManager::new(
  policy? : ProductionIncidentPolicy = ProductionIncidentPolicy::new(),
) -> ProductionIncidentManager {
  { policy, incidents: [], next_id: 1, ingested: 0, grouped: 0, resolved: 0 }
}

///|
pub fn ProductionIncidentManager::policy(
  self : ProductionIncidentManager,
) -> ProductionIncidentPolicy {
  self.policy
}

///|
pub fn ProductionIncidentManager::ingested(
  self : ProductionIncidentManager,
) -> Int {
  self.ingested
}

///|
pub fn ProductionIncidentManager::grouped(
  self : ProductionIncidentManager,
) -> Int {
  self.grouped
}

///|
pub fn ProductionIncidentManager::resolved(
  self : ProductionIncidentManager,
) -> Int {
  self.resolved
}

///|
pub fn ProductionIncidentManager::incident_count(
  self : ProductionIncidentManager,
) -> Int {
  self.incidents.length()
}

///|
pub fn ProductionIncidentManager::incidents(
  self : ProductionIncidentManager,
) -> Array[ProductionIncident] {
  let result : Array[ProductionIncident] = []
  for incident in self.incidents {
    result.push(incident)
  }
  result
}

///|
pub fn ProductionIncidentManager::open_incidents(
  self : ProductionIncidentManager,
) -> Array[ProductionIncident] {
  let result : Array[ProductionIncident] = []
  for incident in self.incidents {
    if incident.is_open() {
      result.push(incident)
    }
  }
  result
}

///|
pub fn ProductionIncidentManager::ingest(
  self : ProductionIncidentManager,
  event : ProductionMonitorEvent,
) -> ProductionIncident {
  self.ingested += 1
  let mut candidate : ProductionIncident? = None
  let mut position = -1
  for i, incident in self.incidents {
    if incident.metric() == event.metric() &&
      incident.is_open() &&
      absolute((event.timestamp() - incident.last_timestamp()).to_double()) <=
      self.policy.grouping_gap().to_double() {
      candidate = Some(incident)
      position = i
      break
    }
  }
  match candidate {
    Some(incident) => {
      ignore(incident.absorb(event))
      self.grouped += 1
      self.incidents[position] = incident
      incident
    }
    None => {
      let incident = ProductionIncident::new(self.next_id, event)
      self.next_id += 1
      self.incidents.push(incident)
      while self.incidents.length() > self.policy.retention() {
        ignore(self.incidents.remove(0))
      }
      incident
    }
  }
}

///|
pub fn ProductionIncidentManager::observe_healthy(
  self : ProductionIncidentManager,
  metric : String,
  timestamp : Int64,
) -> Array[ProductionIncident] {
  let closed : Array[ProductionIncident] = []
  for incident in self.incidents {
    if incident.metric() == metric && incident.is_open() {
      incident.observe_recovery()
      if incident.recovery_observations() >= self.policy.recovery_points() {
        incident.resolve()
        self.resolved += 1
        closed.push(incident)
      }
    }
  }
  ignore(timestamp)
  closed
}

///|
pub fn ProductionIncidentManager::escalate_due(
  self : ProductionIncidentManager,
) -> Array[ProductionIncident] {
  let result : Array[ProductionIncident] = []
  for incident in self.incidents {
    if incident.is_open() &&
      incident.alert_count() >= self.policy.escalation_after() {
      ignore(incident.escalate())
      result.push(incident)
    }
  }
  result
}

///|
pub fn ProductionIncidentManager::reset(
  self : ProductionIncidentManager,
) -> Unit {
  self.incidents.clear()
  self.next_id = 1
  self.ingested = 0
  self.grouped = 0
  self.resolved = 0
}

///|
/// A maintenance interval during which alert delivery is intentionally muted.
pub struct ProductionMaintenanceWindow {
  name : String
  start : Int64
  end : Int64
  reason : String
}

///|
pub fn ProductionMaintenanceWindow::new(
  name : String,
  start : Int64,
  end : Int64,
  reason? : String = "planned maintenance",
) -> ProductionMaintenanceWindow {
  { name, start, end: if end < start { start } else { end }, reason }
}

///|
pub fn ProductionMaintenanceWindow::name(
  self : ProductionMaintenanceWindow,
) -> String {
  self.name
}

///|
pub fn ProductionMaintenanceWindow::start(
  self : ProductionMaintenanceWindow,
) -> Int64 {
  self.start
}

///|
pub fn ProductionMaintenanceWindow::end(
  self : ProductionMaintenanceWindow,
) -> Int64 {
  self.end
}

///|
pub fn ProductionMaintenanceWindow::reason(
  self : ProductionMaintenanceWindow,
) -> String {
  self.reason
}

///|
pub fn ProductionMaintenanceWindow::contains(
  self : ProductionMaintenanceWindow,
  timestamp : Int64,
) -> Bool {
  timestamp >= self.start && timestamp < self.end
}

///|
pub fn ProductionMaintenanceWindow::duration(
  self : ProductionMaintenanceWindow,
) -> Int64 {
  self.end - self.start
}

///|
/// A suppression schedule composed of non-overlapping maintenance windows.
pub struct ProductionSuppressionSchedule {
  windows : Array[ProductionMaintenanceWindow]
  mut suppressed : Int
}

///|
pub fn ProductionSuppressionSchedule::new() -> ProductionSuppressionSchedule {
  { windows: [], suppressed: 0 }
}

///|
pub fn ProductionSuppressionSchedule::add(
  self : ProductionSuppressionSchedule,
  window : ProductionMaintenanceWindow,
) -> Bool {
  for existing in self.windows {
    if window.start() < existing.end() && existing.start() < window.end() {
      return false
    }
  }
  self.windows.push(window)
  true
}

///|
pub fn ProductionSuppressionSchedule::active(
  self : ProductionSuppressionSchedule,
  timestamp : Int64,
) -> ProductionMaintenanceWindow? {
  for window in self.windows {
    if window.contains(timestamp) {
      return Some(window)
    }
  }
  None
}

///|
pub fn ProductionSuppressionSchedule::allow(
  self : ProductionSuppressionSchedule,
  timestamp : Int64,
) -> Bool {
  match self.active(timestamp) {
    None => true
    Some(_) => {
      self.suppressed += 1
      false
    }
  }
}

///|
pub fn ProductionSuppressionSchedule::suppressed(
  self : ProductionSuppressionSchedule,
) -> Int {
  self.suppressed
}

///|
pub fn ProductionSuppressionSchedule::windows(
  self : ProductionSuppressionSchedule,
) -> Array[ProductionMaintenanceWindow] {
  let result : Array[ProductionMaintenanceWindow] = []
  for window in self.windows {
    result.push(window)
  }
  result
}

///|
/// One escalation destination and the delay before it is eligible.
pub struct ProductionEscalationStep {
  channel : String
  delay : Int64
  minimum_severity : AlertSeverity
}

///|
pub fn ProductionEscalationStep::new(
  channel : String,
  delay : Int64,
  minimum_severity? : AlertSeverity = Warning,
) -> ProductionEscalationStep {
  { channel, delay: if delay < 0L { 0L } else { delay }, minimum_severity }
}

///|
pub fn ProductionEscalationStep::channel(
  self : ProductionEscalationStep,
) -> String {
  self.channel
}

///|
pub fn ProductionEscalationStep::delay(
  self : ProductionEscalationStep,
) -> Int64 {
  self.delay
}

///|
pub fn ProductionEscalationStep::minimum_severity(
  self : ProductionEscalationStep,
) -> AlertSeverity {
  self.minimum_severity
}

///|
fn production_severity_rank(severity : AlertSeverity) -> Int {
  match severity {
    Informational => 1
    Warning => 2
    Critical => 3
  }
}

///|
pub fn ProductionEscalationStep::eligible(
  self : ProductionEscalationStep,
  incident : ProductionIncident,
  now : Int64,
) -> Bool {
  production_severity_rank(incident.severity()) >=
  production_severity_rank(self.minimum_severity) &&
  incident.first_timestamp() + self.delay() <= now &&
  incident.is_open()
}

///|
pub struct ProductionEscalationPolicy {
  steps : Array[ProductionEscalationStep]
  mut delivered : Int
}

///|
pub fn ProductionEscalationPolicy::new(
  steps? : Array[ProductionEscalationStep] = [],
) -> ProductionEscalationPolicy {
  { steps, delivered: 0 }
}

///|
pub fn ProductionEscalationPolicy::add(
  self : ProductionEscalationPolicy,
  step : ProductionEscalationStep,
) -> Unit {
  self.steps.push(step)
}

///|
pub fn ProductionEscalationPolicy::steps(
  self : ProductionEscalationPolicy,
) -> Array[ProductionEscalationStep] {
  let result : Array[ProductionEscalationStep] = []
  for step in self.steps {
    result.push(step)
  }
  result
}

///|
pub fn ProductionEscalationPolicy::due(
  self : ProductionEscalationPolicy,
  incident : ProductionIncident,
  now : Int64,
) -> Array[ProductionEscalationStep] {
  let result : Array[ProductionEscalationStep] = []
  let current_level = incident.escalation_level()
  for i, step in self.steps {
    if i >= current_level && step.eligible(incident, now) {
      result.push(step)
    }
  }
  result
}

///|
pub fn ProductionEscalationPolicy::mark_delivered(
  self : ProductionEscalationPolicy,
) -> Unit {
  self.delivered += 1
}

///|
pub fn ProductionEscalationPolicy::delivered(
  self : ProductionEscalationPolicy,
) -> Int {
  self.delivered
}

///|
pub fn ProductionEscalationPolicy::summary(
  self : ProductionEscalationPolicy,
) -> String {
  let entries : Array[String] = []
  for step in self.steps {
    entries.push(step.channel() + "@" + step.delay().to_string())
  }
  entries.join(",")
}

///|
fn production_incident_state_is(
  left : ProductionIncidentState,
  right : ProductionIncidentState,
) -> Bool {
  match (left, right) {
    (OpenIncident, OpenIncident) => true
    (AcknowledgedIncident, AcknowledgedIncident) => true
    (SnoozedIncident, SnoozedIncident) => true
    (ResolvedIncident, ResolvedIncident) => true
    (ReopenedIncident, ReopenedIncident) => true
    _ => false
  }
}
