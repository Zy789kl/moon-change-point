///|
pub struct EventHistory {
  capacity : Int
  events : Array[AlertEvent]
  mut total : Int
}

///|
pub fn EventHistory::new(capacity? : Int = 256) -> EventHistory {
  { capacity: if capacity < 1 { 1 } else { capacity }, events: [], total: 0 }
}

///|
pub fn EventHistory::push(self : EventHistory, event : AlertEvent) -> Unit {
  self.events.push(event)
  self.total += 1
  if self.events.length() > self.capacity {
    ignore(self.events.remove(0))
  }
}

///|
pub fn EventHistory::length(self : EventHistory) -> Int {
  self.events.length()
}

///|
pub fn EventHistory::total(self : EventHistory) -> Int {
  self.total
}

///|
pub fn EventHistory::events(self : EventHistory) -> Array[AlertEvent] {
  let result : Array[AlertEvent] = []
  for event in self.events {
    result.push(event)
  }
  result
}

///|
pub fn EventHistory::critical_count(self : EventHistory) -> Int {
  let mut count = 0
  for event in self.events {
    if severity_name(event.point.severity) == "critical" {
      count += 1
    }
  }
  count
}

///|
pub fn EventHistory::unsuppressed_count(self : EventHistory) -> Int {
  let mut count = 0
  for event in self.events {
    if !event.suppressed {
      count += 1
    }
  }
  count
}

///|
pub fn EventHistory::latest(self : EventHistory) -> AlertEvent? {
  if self.events.length() == 0 {
    None
  } else {
    Some(self.events[self.events.length() - 1])
  }
}

///|
pub fn deduplicate_events(
  events : Array[AlertEvent],
  minimum_gap : Int64,
) -> Array[AlertEvent] {
  let result : Array[AlertEvent] = []
  for event in events {
    let mut duplicate = false
    for previous in result {
      if previous.metric == event.metric &&
        absolute((previous.point.timestamp - event.point.timestamp).to_double()) <=
        minimum_gap.to_double() {
        duplicate = true
      }
    }
    if !duplicate {
      result.push(event)
    }
  }
  result
}

///|
pub fn event_rate(
  events : Array[AlertEvent],
  start : Int64,
  end : Int64,
) -> Double {
  if end <= start {
    return 0.0
  }
  events.length().to_double() / (end - start).to_double()
}
