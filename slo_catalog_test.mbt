///|
test "empty SLO window is fully available" {
  let window = SloWindow::new()
  assert_eq(window.total(), 0)
  assert_eq(window.bad(), 0)
  assert_eq(window.availability(), 1.0)
  assert_eq(window.change_rate(), 0.0)
}

///|
test "SLO window counts bad and severe evidence" {
  let window = SloWindow::new()
  window.observe(DetectionResult::quiet())
  window.observe(DetectionResult::new(true, 0.7, 0.8, Increase, 1))
  window.observe(DetectionResult::new(true, 1.0, 1.0, Increase, 2))
  assert_eq(window.total(), 3)
  assert_eq(window.changed(), 2)
  assert_eq(window.bad(), 2)
  assert_eq(window.severe(), 1)
  assert_true(window.availability() < 1.0)
}

///|
test "error budget is never negative" {
  assert_eq(error_budget(0.95, 0.99), 0.0)
  assert_true(error_budget(0.999, 0.99) >= 0.0)
  assert_true(error_budget(2.0, -1.0) >= 0.0)
}

///|
test "burn rate increases with bad evidence" {
  let empty = SloWindow::new()
  let bad = SloWindow::new()
  for _ in 0..<10 {
    bad.observe(DetectionResult::new(true, 1.0, 1.0, Increase, 1))
  }
  assert_eq(burn_rate(empty, 0.99), 0.0)
  assert_true(burn_rate(bad, 0.99) > 1.0)
}

///|
test "SLO evaluation identifies a breach" {
  let window = SloWindow::new()
  for _ in 0..<5 {
    window.observe(DetectionResult::new(true, 1.0, 1.0, Increase, 1))
  }
  let report = evaluate_slo(window, target=0.99, burn_limit=1.0)
  assert_true(report.breached())
  assert_true(report.summary().contains("freeze"))
}

///|
test "SLO evaluation recommends monitoring near a limit" {
  let window = SloWindow::new()
  window.observe(DetectionResult::new(true, 0.7, 0.7, Increase, 1))
  let report = evaluate_slo(window, target=0.5, burn_limit=10.0)
  assert_true(report.availability() <= 1.0)
  assert_true(report.budget() >= 0.0)
}

///|
test "SLO tracker closes repeatable periods" {
  let tracker = SloTracker::new(target=0.99)
  tracker.observe(DetectionResult::quiet())
  ignore(tracker.close_period())
  ignore(tracker.close_period())
  assert_eq(tracker.periods(), 2)
  assert_eq(tracker.window().total(), 1)
}

///|
test "detector catalog is populated" {
  let catalog = detector_catalog()
  assert_true(catalog.length() >= 6)
  assert_true(online_detector_count() >= 4)
  assert_true(robust_detector_count() >= 2)
}

///|
test "detector catalog names are stable" {
  let names = detector_names()
  assert_true(names.contains("CUSUM"))
  assert_true(names.contains("Robust-Z"))
  assert_true(names.contains("Mahalanobis"))
}

///|
test "catalog lookup returns none for unknown algorithms" {
  match find_detector("does-not-exist") {
    None => ()
    Some(_) => fail("unknown detector found")
  }
  match find_detector("CUSUM") {
    None => fail("CUSUM missing")
    Some(spec) => assert_true(spec.online)
  }
}

///|
test "catalog markdown is suitable for documentation" {
  let markdown = catalog_markdown()
  assert_true(markdown.contains("detector"))
  assert_true(markdown.contains("Mahalanobis"))
  assert_true(markdown.contains("threshold"))
}

///|
test "recommended detector follows workload dimensions" {
  assert_eq(recommended_detector(false, false, false), "CUSUM")
  assert_eq(recommended_detector(false, false, true), "Robust-Z")
  assert_eq(recommended_detector(true, false, true), "Mahalanobis")
  assert_eq(recommended_detector(false, true, false), "Binary segmentation")
}

///|
test "detector specification summary names the family" {
  match find_detector("CUSUM") {
    None => fail("CUSUM missing")
    Some(spec) => assert_true(spec.summary().contains("sequential"))
  }
}
