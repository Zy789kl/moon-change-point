///|
test "cusum detects mean shift" {
  let detector = Cusum::new(target_mean=0.0, control_limit=5.0, drift=0.5)

  // Normal data
  for _ in 0..<=5 {
    assert_eq(detector.update(0.1), false)
  }

  // Mean shift
  let mut detected = false
  for _ in 0..<=10 {
    if detector.update(2.0) {
      detected = true
      break
    }
  }
  assert_eq(detected, true)
}

///|
test "cusum negative mean shift" {
  let detector = Cusum::new(target_mean=0.0, control_limit=5.0, drift=0.5)

  let mut detected = false
  for _ in 0..<=10 {
    if detector.update(-2.0) {
      detected = true
      break
    }
  }
  assert_eq(detected, true)
}
