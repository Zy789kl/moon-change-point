///|
test "page-hinkley detects mean shift" {
  let detector = PageHinkley::new(
    target_mean=0.0,
    control_limit=5.0,
    delta=0.5,
    alpha=0.99,
  )

  // Normal data
  for _ in 0..<=5 {
    assert_eq(detector.update(0.1), false)
  }

  // Mean shift
  let mut detected = false
  for _ in 0..<=20 {
    if detector.update(2.0) {
      detected = true
      break
    }
  }
  assert_eq(detected, true)
}

///|
test "page-hinkley recovers from small noise" {
  let detector = PageHinkley::new(
    target_mean=0.0,
    control_limit=5.0,
    delta=0.5,
    alpha=0.99,
  )

  let mut detected = false
  for _ in 0..<=10 {
    if detector.update(0.5) {
      detected = true
      break
    }
    if detector.update(-0.5) {
      detected = true
      break
    }
  }
  assert_eq(detected, false)
}
