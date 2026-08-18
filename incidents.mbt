///|
/// Groups nearby alert events into incidents for operators.
pub struct Incident {
  metric : String
  mut first_timestamp : Int64
  mut last_timestamp : Int64
  mut alerts : Int
  mut critical : Int
  mut maximum_score : Double
  mut direction : ChangeDirection
}

///|
pub fn Incident::empty(metric : String) -> Incident {
  {
    metric,
    first_timestamp: 0L,
    last_timestamp: 0L,
    alerts: 0,
    critical: 0,
    maximum_score: 0.0,
    direction: Unknown,
  }
}

///|
pub fn Incident::add(self : Incident, event : AlertEvent) -> Unit {
  if self.alerts == 0 {
    self.first_timestamp = event.point.timestamp
    self.direction = event.point.direction
  }
  self.last_timestamp = event.point.timestamp
  self.alerts += 1
  if severity_name(event.point.severity) == "critical" {
    self.critical += 1
  }
  if event.point.score > self.maximum_score {
    self.maximum_score = event.point.score
    self.direction = event.point.direction
  }
}

///|
pub fn Incident::duration(self : Incident) -> Int64 {
  self.last_timestamp - self.first_timestamp
}

///|
pub fn Incident::is_critical(self : Incident) -> Bool {
  self.critical > 0 || self.maximum_score >= 0.9
}

///|
pub fn Incident::summary(self : Incident) -> String {
  self.metric +
  "@" +
  self.first_timestamp.to_string() +
  "-" +
  self.last_timestamp.to_string() +
  " alerts=" +
  self.alerts.to_string() +
  " score=" +
  self.maximum_score.to_string()
}

///|
pub fn cluster_incidents(
  events : Array[AlertEvent],
  maximum_gap : Int64,
) -> Array[Incident] {
  let result : Array[Incident] = []
  let gap = if maximum_gap < 0L { 0L } else { maximum_gap }
  for event in events {
    let mut matched = false
    if result.length() > 0 {
      let last = result[result.length() - 1]
      if last.metric == event.metric &&
        event.point.timestamp - last.last_timestamp <= gap {
        last.add(event)
        matched = true
      }
    }
    if !matched {
      let incident = Incident::empty(event.metric)
      incident.add(event)
      result.push(incident)
    }
  }
  result
}

///|
pub fn critical_incident_count(incidents : Array[Incident]) -> Int {
  let mut count = 0
  for incident in incidents {
    if incident.is_critical() {
      count += 1
    }
  }
  count
}

///|
pub fn incident_alert_count(incidents : Array[Incident]) -> Int {
  let mut count = 0
  for incident in incidents {
    count += incident.alerts
  }
  count
}

///|
pub fn incidents_markdown(incidents : Array[Incident]) -> String {
  let mut output = "| metric | first | last | alerts | critical | max score | direction |\n|---|---:|---:|---:|---:|---:|---|\n"
  for incident in incidents {
    output = output +
      "| " +
      incident.metric +
      " | " +
      incident.first_timestamp.to_string() +
      " | " +
      incident.last_timestamp.to_string() +
      " | " +
      incident.alerts.to_string() +
      " | " +
      incident.critical.to_string() +
      " | " +
      incident.maximum_score.to_string() +
      " | " +
      direction_name(incident.direction) +
      " |\n"
  }
  output
}

///|
pub fn incident_rate(
  incidents : Array[Incident],
  start : Int64,
  end : Int64,
) -> Double {
  if end <= start {
    0.0
  } else {
    incidents.length().to_double() / (end - start).to_double()
  }
}
