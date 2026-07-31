///|
test "detector with cusum and suppression" {
  let cusum = Cusum::new(target_mean=0.0, control_limit=5.0, drift=0.5)
  let detector = Detector::new(CusumDetector(cusum), suppression_limit=2)

  // Normal data
  for _ in 0..<=5 {
    assert_eq(detector.update(0.1), false)
  }

  // Shift starts
  // The underlying CUSUM will detect it at some point, and then suppression should kick in
  let mut alert_count = 0
  for _ in 0..<=20 {
    if detector.update(3.0) {
      alert_count += 1
    }
  }
  // Because of suppression, it won't alert on every single point after detection
  assert_true(alert_count > 0 && alert_count < 20)
}

///|
test "detector with page-hinkley" {
  let ph = PageHinkley::new(
    target_mean=0.0,
    control_limit=5.0,
    delta=0.5,
    alpha=0.99,
  )
  let detector = Detector::new(PageHinkleyDetector(ph), suppression_limit=1)

  // Normal
  assert_eq(detector.update(0.1), false)
}

///|
test "detector with bayesian" {
  let b = Bayesian::new(hazard_rate=0.01)
  let detector = Detector::new(BayesianDetector(b), suppression_limit=1)

  assert_eq(detector.update(0.1), false)
}
