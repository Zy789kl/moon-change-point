///|
test "threshold reports calculate confusion metrics" {
  let observations : Array[ScoreObservation] = [
    ScoreObservation::new(0.1, false),
    ScoreObservation::new(0.9, true),
    ScoreObservation::new(0.8, false),
    ScoreObservation::new(0.2, true),
  ]
  let report = evaluate_threshold(observations, 0.5)
  assert_eq(report.true_positives, 1)
  assert_eq(report.false_positives, 1)
  assert_eq(report.false_negatives, 1)
  assert_true(report.f1 > 0.0)
}

///|
test "calibrator keeps bounded history" {
  let calibrator = ScoreCalibrator::new(max_observations=3)
  for i in 0..<10 {
    calibrator.push(i.to_double() / 10.0, i % 2 == 0)
  }
  assert_eq(calibrator.count(), 3)
  assert_true(calibrator.positive_weight() >= 0.0)
  assert_true(calibrator.best([0.2, 0.5, 0.8]).threshold >= 0.0)
}

///|
test "calibration bins cover score interval" {
  let observations : Array[ScoreObservation] = [
    ScoreObservation::new(0.0, true),
    ScoreObservation::new(1.0, false),
  ]
  let bins = calibration_bins(observations, bins=4)
  assert_eq(bins.length(), 4)
  assert_eq(bins[0], 1.0)
  assert_eq(bins[3], 0.0)
}

///|
test "consecutive rule requires repeated positives" {
  let rule = ConsecutiveRule::new(required=3)
  assert_eq(rule.push(true), false)
  assert_eq(rule.push(true), false)
  assert_eq(rule.push(true), true)
  assert_eq(rule.push(false), false)
}

///|
test "hysteresis prevents flapping" {
  let rule = HysteresisRule::new(enter_threshold=1.0, exit_threshold=0.5)
  assert_eq(rule.push(0.9), false)
  assert_eq(rule.push(1.1), true)
  assert_eq(rule.push(0.8), true)
  assert_eq(rule.push(0.4), false)
}

///|
test "vote rule counts recent positives only" {
  let rule = VoteRule::new(size=3, required=2)
  assert_eq(rule.push(true), false)
  assert_eq(rule.push(true), true)
  assert_eq(rule.push(false), true)
  assert_eq(rule.push(false), false)
  assert_eq(rule.votes(), 1)
}

///|
test "alert budget refills and reports suppression" {
  let budget = AlertBudget::new(capacity=1, refill=0.0)
  assert_eq(budget.allow(), true)
  assert_eq(budget.allow(), false)
  assert_eq(budget.suppressed(), 1)
  budget.tick()
  assert_eq(budget.allow(), false)
}
