///|
test "recovery plan maps severity to useful action" {
  let informational = RecoveryPlan::for_result(
    DetectionResult::new(false, 0.1, 0.2, Unknown, 0),
  )
  let warning = RecoveryPlan::for_result(
    DetectionResult::new(true, 0.7, 0.8, Increase, 1),
  )
  let critical = RecoveryPlan::for_result(
    DetectionResult::new(true, 1.0, 1.0, Increase, 2),
  )
  assert_eq(severity_name(informational.severity), "informational")
  assert_eq(severity_name(warning.severity), "warning")
  assert_eq(severity_name(critical.severity), "critical")
  assert_true(
    recovery_priority(DetectionResult::new(true, 1.0, 1.0, Increase, 2)) >
    recovery_priority(DetectionResult::new(true, 0.7, 0.8, Increase, 1)),
  )
}

///|
test "cooldown schedule grows exponentially" {
  let plan = RecoveryPlan::for_result(
    DetectionResult::new(true, 0.7, 0.8, Increase, 1),
  )
  let schedule = cooldown_schedule(plan, 4)
  assert_eq(schedule.length(), 4)
  assert_eq(schedule[0], plan.cooldown)
  assert_true(schedule[1] >= schedule[0])
  assert_true(schedule[3] >= schedule[2])
}

///|
test "recovery tracker closes only after both acknowledgements" {
  let plan = RecoveryPlan::for_result(
    DetectionResult::new(true, 0.9, 0.9, Increase, 1),
  )
  let tracker = RecoveryTracker::new(plan)
  assert_eq(tracker.attempts(), 0)
  assert_true(!tracker.is_closed())
  ignore(tracker.attempt())
  tracker.acknowledge()
  assert_true(!tracker.is_closed())
  tracker.mark_recovered()
  assert_true(tracker.is_closed())
}

///|
test "recovery escalation follows plan threshold" {
  let plan = RecoveryPlan::for_result(
    DetectionResult::new(true, 0.7, 0.8, Increase, 1),
  )
  assert_true(!should_escalate(plan, 0.1))
  assert_true(should_escalate(plan, 0.9))
  assert_true(recovery_message(plan).contains("verify"))
}

///|
test "threshold quantiles and MAD are monotonic" {
  let scores = [0.0, 0.1, 0.2, 0.8, 1.0]
  assert_true(
    threshold_from_quantile(scores, 0.1) >= threshold_from_quantile(scores, 0.5),
  )
  assert_true(threshold_from_mad(scores) >= median(scores))
  assert_true(threshold_from_mean(scores) >= mean(scores))
}

///|
test "threshold grid handles invalid step counts" {
  assert_eq(threshold_grid(0.0, 1.0, 0), [])
  assert_eq(threshold_grid(0.0, 1.0, 1), [0.0])
  assert_eq(threshold_grid(0.0, 1.0, 3), [0.0, 0.5, 1.0])
}

///|
test "classification metrics tolerate mismatched lengths" {
  let scores = [0.1, 0.8, 0.9]
  let labels = [false, true]
  assert_true(score_precision(scores, labels, 0.5) >= 0.0)
  assert_true(score_recall(scores, labels, 0.5) >= 0.0)
  assert_true(score_f1(scores, labels, 0.5) >= 0.0)
}

///|
test "best F1 threshold returns a candidate" {
  let result = best_f1_threshold([0.1, 0.8, 0.9], [false, true, true], [
    0.2, 0.5, 0.95,
  ])
  assert_true(
    result.threshold == 0.2 ||
    result.threshold == 0.5 ||
    result.threshold == 0.95,
  )
  assert_true(result.score >= 0.0 && result.score <= 1.0)
}

///|
test "adaptive threshold respects bounds and counts observations" {
  let threshold = AdaptiveThreshold::new(
    initial=0.5,
    rate=0.2,
    minimum=0.2,
    maximum=0.8,
  )
  ignore(threshold.observe(0.9, true))
  ignore(threshold.observe(0.1, false))
  assert_eq(threshold.count(), 2)
  assert_true(threshold.value() >= 0.2 && threshold.value() <= 0.8)
}

///|
test "threshold points retain the score order" {
  let points = threshold_points([0.1, 0.9, 0.2], 0.5)
  assert_eq(points.length(), 3)
  assert_true(!points[0].accepted)
  assert_true(points[1].accepted)
  assert_eq(points[2].index, 2)
}

///|
test "recovery reports are line oriented" {
  let plans = [
    RecoveryPlan::for_result(DetectionResult::new(false, 0.1, 0.2, Unknown, 0)),
  ]
  let report = recovery_report(plans)
  assert_true(report.contains("severity,action"))
  assert_true(report.contains("informational"))
}
