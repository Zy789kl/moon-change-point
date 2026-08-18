///|
/// Recovery guidance and cooldown state for alert consumers.
pub struct RecoveryPlan {
  severity : AlertSeverity
  immediate_action : String
  verification_window : Int
  cooldown : Int
  escalation_score : Double
}

///|
pub fn RecoveryPlan::for_result(result : DetectionResult) -> RecoveryPlan {
  let severity = severity_from_score(result.score)
  match severity {
    Informational =>
      {
        severity,
        immediate_action: "continue monitoring",
        verification_window: 5,
        cooldown: 2,
        escalation_score: 0.6,
      }
    Warning =>
      {
        severity,
        immediate_action: "inspect recent changes",
        verification_window: 10,
        cooldown: 5,
        escalation_score: 0.8,
      }
    Critical =>
      {
        severity,
        immediate_action: "page service owner and preserve evidence",
        verification_window: 20,
        cooldown: 10,
        escalation_score: 0.95,
      }
  }
}

///|
pub fn recovery_priority(result : DetectionResult) -> Int {
  match severity_from_score(result.score) {
    Informational => 1
    Warning => 2
    Critical => 3
  }
}

///|
pub fn cooldown_schedule(plan : RecoveryPlan, attempts : Int) -> Array[Int] {
  let result : Array[Int] = []
  let safe_attempts = if attempts < 0 { 0 } else { attempts }
  let mut delay = plan.cooldown
  for _ in 0..<safe_attempts {
    result.push(delay)
    delay = if delay > 1073741823 { 2147483647 } else { delay * 2 }
  }
  result
}

///|
pub fn should_escalate(plan : RecoveryPlan, score : Double) -> Bool {
  score >= plan.escalation_score
}

///|
pub struct RecoveryTracker {
  plan : RecoveryPlan
  mut attempts : Int
  mut acknowledged : Bool
  mut recovered : Bool
}

///|
pub fn RecoveryTracker::new(plan : RecoveryPlan) -> RecoveryTracker {
  { plan, attempts: 0, acknowledged: false, recovered: false }
}

///|
pub fn RecoveryTracker::attempt(self : RecoveryTracker) -> Int {
  self.attempts += 1
  self.attempts
}

///|
pub fn RecoveryTracker::acknowledge(self : RecoveryTracker) -> Unit {
  self.acknowledged = true
}

///|
pub fn RecoveryTracker::mark_recovered(self : RecoveryTracker) -> Unit {
  self.recovered = true
}

///|
pub fn RecoveryTracker::attempts(self : RecoveryTracker) -> Int {
  self.attempts
}

///|
pub fn RecoveryTracker::is_closed(self : RecoveryTracker) -> Bool {
  self.recovered && self.acknowledged
}

///|
pub fn recovery_message(plan : RecoveryPlan) -> String {
  severity_name(plan.severity) +
  ": " +
  plan.immediate_action +
  "; verify for " +
  plan.verification_window.to_string() +
  " samples"
}

///|
pub fn recovery_report(plans : Array[RecoveryPlan]) -> String {
  let mut output = "severity,action,verification_window,cooldown\n"
  for plan in plans {
    output = output +
      severity_name(plan.severity) +
      "," +
      plan.immediate_action +
      "," +
      plan.verification_window.to_string() +
      "," +
      plan.cooldown.to_string() +
      "\n"
  }
  output
}
