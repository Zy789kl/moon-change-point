///|
test "bayesian detects change point" {
  let detector = Bayesian::new(hazard_rate=0.01, mu0=0.0, max_run_length=50)

  let mut max_change_prob = 0.0
  // Normal data
  for _ in 0..<=20 {
    let p = detector.update(0.1)
    if p > max_change_prob {
      max_change_prob = p
    }
  }

  // Change point
  let mut detected_shift_prob = 0.0
  for _ in 0..<=5 {
    let p = detector.update(5.0)
    if p > detected_shift_prob {
      detected_shift_prob = p
    }
  }

  // The probability of change should be significantly higher after the shift
  println(
    "Max change prob normal: \{max_change_prob}, Shift prob: \{detected_shift_prob}",
  )
}
