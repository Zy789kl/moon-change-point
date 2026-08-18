///|
fn routed_event(score : Double, suppressed : Bool) -> AlertEvent {
  let result = DetectionResult::new(score >= 0.6, score, score, Increase, 1)
  let point = ChangePoint::from_result(
    SignalPoint::new(1L, score),
    result,
    "router",
    0.0,
  )
  AlertEvent::new("router", point, suppressed~)
}

///|
test "informational alerts go to logs" {
  let decision = route_alert(routed_event(0.1, false))
  assert_eq(decision.channel, "log")
  assert_eq(decision.priority, 1)
  assert_true(!decision.is_page())
}

///|
test "warning alerts become tickets" {
  let decision = route_alert(routed_event(0.7, false))
  assert_eq(decision.channel, "ticket")
  assert_eq(decision.priority, 2)
  assert_true(decision.summary().contains("router"))
}

///|
test "critical alerts page the owner" {
  let decision = route_alert(routed_event(1.0, false))
  assert_eq(decision.channel, "page")
  assert_eq(decision.priority, 3)
  assert_true(decision.is_page())
}

///|
test "suppressed alerts are omitted from routing" {
  let decisions = route_alerts([
    routed_event(1.0, true),
    routed_event(0.7, false),
  ])
  assert_eq(decisions.length(), 1)
  assert_eq(decisions[0].channel, "ticket")
}

///|
test "routing counters summarize priorities" {
  let decisions = route_alerts([
    routed_event(1.0, false),
    routed_event(0.7, false),
    routed_event(0.1, false),
  ])
  assert_eq(page_count(decisions), 1)
  assert_eq(highest_priority(decisions), 3)
  assert_true(routing_summary(decisions).contains("channel,priority"))
}

///|
test "routing decision acknowledgement is explicit" {
  let decision = route_alert(routed_event(1.0, false))
  assert_true(!decision.acknowledged)
  decision.acknowledge()
  assert_true(decision.acknowledged)
}

///|
test "routing budget permits critical alerts beyond capacity" {
  let budget = RoutingBudget::new(capacity=1)
  let warning = route_alert(routed_event(0.7, false))
  let critical = route_alert(routed_event(1.0, false))
  assert_true(budget.allow(warning))
  assert_true(budget.allow(critical))
  assert_eq(budget.used(), 2)
  assert_eq(budget.remaining(), 0)
}

///|
test "routing budget suppresses low priority overflow" {
  let budget = RoutingBudget::new(capacity=1)
  let warning = route_alert(routed_event(0.7, false))
  assert_true(budget.allow(warning))
  assert_true(!budget.allow(warning))
  assert_eq(budget.used(), 1)
}

///|
test "zero routing capacity is safe" {
  let budget = RoutingBudget::new(capacity=-1)
  let informational = route_alert(routed_event(0.1, false))
  assert_true(!budget.allow(informational))
  assert_eq(budget.remaining(), 0)
}

///|
test "route_alerts retains input order" {
  let decisions = route_alerts([
    routed_event(0.1, false),
    routed_event(1.0, false),
  ])
  assert_eq(decisions[0].priority, 1)
  assert_eq(decisions[1].priority, 3)
}

///|
test "routing summary has one row per decision" {
  let decisions = route_alerts([
    routed_event(0.1, false),
    routed_event(0.7, false),
  ])
  let summary = routing_summary(decisions)
  assert_true(summary.contains("log,1"))
  assert_true(summary.contains("ticket,2"))
}

///|
test "page count is zero for empty decisions" {
  assert_eq(page_count([]), 0)
  assert_eq(highest_priority([]), 0)
}

///|
test "routing is composable with incident summaries" {
  let events = [routed_event(1.0, false), routed_event(0.7, false)]
  let incidents = cluster_incidents(events, 2L)
  let decisions = route_alerts(events)
  assert_eq(incidents.length(), 1)
  assert_eq(page_count(decisions), 1)
}

///|
test "routing reason is non empty" {
  let decision = route_alert(routed_event(0.7, false))
  assert_true(decision.reason.length() > 0)
}

///|
test "routing budget tracks repeated critical events" {
  let budget = RoutingBudget::new(capacity=0)
  for _ in 0..<4 {
    assert_true(budget.allow(route_alert(routed_event(1.0, false))))
  }
  assert_eq(budget.used(), 4)
}
