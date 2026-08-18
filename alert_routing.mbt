///|
/// Converts alert severity into deterministic notification channels.
pub struct RoutingDecision {
  metric : String
  channel : String
  priority : Int
  mut acknowledged : Bool
  reason : String
}

///|
pub fn RoutingDecision::new(
  metric : String,
  channel : String,
  priority : Int,
  reason : String,
) -> RoutingDecision {
  { metric, channel, priority, acknowledged: false, reason }
}

///|
pub fn RoutingDecision::acknowledge(self : RoutingDecision) -> Unit {
  self.acknowledged = true
}

///|
pub fn RoutingDecision::is_page(self : RoutingDecision) -> Bool {
  self.channel == "page"
}

///|
pub fn RoutingDecision::summary(self : RoutingDecision) -> String {
  self.metric +
  ":" +
  self.channel +
  ":priority=" +
  self.priority.to_string() +
  ":" +
  self.reason
}

///|
pub fn route_alert(alert : AlertEvent) -> RoutingDecision {
  match alert.point.severity {
    Informational =>
      RoutingDecision::new(alert.metric, "log", 1, "record for trend analysis")
    Warning =>
      RoutingDecision::new(
        alert.metric,
        "ticket",
        2,
        "inspect within the current shift",
      )
    Critical =>
      RoutingDecision::new(alert.metric, "page", 3, "wake the service owner")
  }
}

///|
pub fn route_alerts(alerts : Array[AlertEvent]) -> Array[RoutingDecision] {
  let result : Array[RoutingDecision] = []
  for alert in alerts {
    if !alert.suppressed {
      result.push(route_alert(alert))
    }
  }
  result
}

///|
pub fn page_count(decisions : Array[RoutingDecision]) -> Int {
  let mut count = 0
  for decision in decisions {
    if decision.is_page() {
      count += 1
    }
  }
  count
}

///|
pub fn highest_priority(decisions : Array[RoutingDecision]) -> Int {
  let mut priority = 0
  for decision in decisions {
    if decision.priority > priority {
      priority = decision.priority
    }
  }
  priority
}

///|
pub fn routing_summary(decisions : Array[RoutingDecision]) -> String {
  let mut output = "channel,priority,metric\n"
  for decision in decisions {
    output = output +
      decision.channel +
      "," +
      decision.priority.to_string() +
      "," +
      decision.metric +
      "\n"
  }
  output
}

///|
pub struct RoutingBudget {
  capacity : Int
  mut used : Int
}

///|
pub fn RoutingBudget::new(capacity? : Int = 10) -> RoutingBudget {
  { capacity: if capacity < 0 { 0 } else { capacity }, used: 0 }
}

///|
pub fn RoutingBudget::allow(
  self : RoutingBudget,
  decision : RoutingDecision,
) -> Bool {
  if decision.priority >= 3 || self.used < self.capacity {
    self.used += 1
    true
  } else {
    false
  }
}

///|
pub fn RoutingBudget::used(self : RoutingBudget) -> Int {
  self.used
}

///|
pub fn RoutingBudget::remaining(self : RoutingBudget) -> Int {
  if self.capacity > self.used {
    self.capacity - self.used
  } else {
    0
  }
}
