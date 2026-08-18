///|
fn incident_event(
  metric : String,
  timestamp : Int64,
  score : Double,
) -> AlertEvent {
  let result = DetectionResult::new(
    score >= 0.6,
    score,
    score,
    Increase,
    timestamp.to_int(),
  )
  let point = ChangePoint::from_result(
    SignalPoint::new(timestamp, score),
    result,
    "cusum",
    0.0,
  )
  AlertEvent::new(metric, point)
}

///|
test "empty incident is neutral" {
  let incident = Incident::empty("metric")
  assert_eq(incident.duration(), 0L)
  assert_eq(incident.alerts, 0)
  assert_true(!incident.is_critical())
}

///|
test "incident accumulates alerts and maximum score" {
  let incident = Incident::empty("metric")
  incident.add(incident_event("metric", 10L, 0.7))
  incident.add(incident_event("metric", 12L, 1.0))
  assert_eq(incident.alerts, 2)
  assert_eq(incident.first_timestamp, 10L)
  assert_eq(incident.last_timestamp, 12L)
  assert_eq(incident.maximum_score, 1.0)
  assert_true(incident.is_critical())
}

///|
test "incident clustering uses metric and gap" {
  let events = [
    incident_event("a", 1L, 0.7),
    incident_event("a", 3L, 0.8),
    incident_event("a", 20L, 0.9),
    incident_event("b", 21L, 0.9),
  ]
  let incidents = cluster_incidents(events, 5L)
  assert_eq(incidents.length(), 3)
  assert_eq(incidents[0].alerts, 2)
  assert_eq(incidents[1].metric, "a")
  assert_eq(incidents[2].metric, "b")
}

///|
test "negative incident gap means exact timestamp only" {
  let events = [
    incident_event("a", 1L, 0.7),
    incident_event("a", 1L, 0.8),
    incident_event("a", 2L, 0.9),
  ]
  let incidents = cluster_incidents(events, -1L)
  assert_eq(incidents.length(), 2)
}

///|
test "incident aggregates are useful for counters" {
  let incidents = cluster_incidents(
    [incident_event("a", 1L, 0.7), incident_event("a", 2L, 0.9)],
    3L,
  )
  assert_eq(incident_alert_count(incidents), 2)
  assert_eq(critical_incident_count(incidents), 1)
  assert_true(incident_rate(incidents, 0L, 10L) > 0.0)
}

///|
test "incident exports contain operator columns" {
  let incidents = cluster_incidents([incident_event("a", 1L, 0.7)], 3L)
  let markdown = incidents_markdown(incidents)
  assert_true(markdown.contains("metric"))
  assert_true(markdown.contains("max score"))
  assert_true(incidents[0].summary().contains("alerts=1"))
}

///|
test "incident rate is zero on invalid intervals" {
  assert_eq(incident_rate([], 1L, 1L), 0.0)
  assert_eq(incident_rate([], 2L, 1L), 0.0)
}

///|
test "quiet events remain non critical" {
  let event = incident_event("a", 1L, 0.1)
  let incidents = cluster_incidents([event], 0L)
  assert_eq(critical_incident_count(incidents), 0)
}

///|
test "catalog and SLO can feed incident consumers" {
  let names = detector_names()
  let window = SloWindow::new()
  window.observe(DetectionResult::new(true, 0.9, 0.9, Increase, 1))
  let report = evaluate_slo(window)
  assert_true(names.length() > 0)
  assert_true(report.burn() >= 0.0)
}
