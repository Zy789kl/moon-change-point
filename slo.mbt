///|
/// Service-level indicators derived from change-point evidence.
pub struct SloWindow {
  mut total : Int
  mut bad : Int
  mut changed : Int
  mut severe : Int
}

///|
pub fn SloWindow::new() -> SloWindow {
  { total: 0, bad: 0, changed: 0, severe: 0 }
}

///|
pub fn SloWindow::observe(self : SloWindow, result : DetectionResult) -> Unit {
  self.total += 1
  if result.changed {
    self.changed += 1
  }
  if result.score >= 0.6 {
    self.bad += 1
  }
  if result.score >= 0.9 {
    self.severe += 1
  }
}

///|
pub fn SloWindow::total(self : SloWindow) -> Int {
  self.total
}

///|
pub fn SloWindow::bad(self : SloWindow) -> Int {
  self.bad
}

///|
pub fn SloWindow::changed(self : SloWindow) -> Int {
  self.changed
}

///|
pub fn SloWindow::severe(self : SloWindow) -> Int {
  self.severe
}

///|
pub fn SloWindow::availability(self : SloWindow) -> Double {
  if self.total == 0 {
    1.0
  } else {
    1.0 - self.bad.to_double() / self.total.to_double()
  }
}

///|
pub fn SloWindow::change_rate(self : SloWindow) -> Double {
  if self.total == 0 {
    0.0
  } else {
    self.changed.to_double() / self.total.to_double()
  }
}

///|
pub fn error_budget(availability : Double, target : Double) -> Double {
  let safe_target = clamp_probability(target)
  let safe_availability = clamp_probability(availability)
  if safe_availability >= safe_target {
    safe_availability - safe_target
  } else {
    0.0
  }
}

///|
pub fn burn_rate(window : SloWindow, target : Double) -> Double {
  let allowed = 1.0 - clamp_probability(target)
  if allowed <= 0.0 {
    if window.bad() > 0 {
      1.7976931348623157e308
    } else {
      0.0
    }
  } else {
    (1.0 - window.availability()) / allowed
  }
}

///|
pub struct SloReport {
  window : SloWindow
  target : Double
  budget : Double
  burn : Double
  breached : Bool
  recommendation : String
}

///|
pub fn evaluate_slo(
  window : SloWindow,
  target? : Double = 0.99,
  burn_limit? : Double = 1.0,
) -> SloReport {
  let safe_target = clamp_probability(target)
  let budget = error_budget(window.availability(), safe_target)
  let burn = burn_rate(window, safe_target)
  let breached = burn > burn_limit
  let recommendation = if breached {
    "freeze risky changes and investigate"
  } else if burn > burn_limit * 0.5 {
    "watch the error budget closely"
  } else {
    "within budget"
  }
  { window, target: safe_target, budget, burn, breached, recommendation }
}

///|
pub fn SloReport::availability(self : SloReport) -> Double {
  self.window.availability()
}

///|
pub fn SloReport::budget(self : SloReport) -> Double {
  self.budget
}

///|
pub fn SloReport::burn(self : SloReport) -> Double {
  self.burn
}

///|
pub fn SloReport::breached(self : SloReport) -> Bool {
  self.breached
}

///|
pub fn SloReport::summary(self : SloReport) -> String {
  "availability=\{self.availability()},budget=\{self.budget},burn=\{self.burn},breached=\{self.breached},recommendation=\{self.recommendation}"
}

///|
pub struct SloTracker {
  window : SloWindow
  target : Double
  burn_limit : Double
  mut periods : Int
}

///|
pub fn SloTracker::new(
  target? : Double = 0.99,
  burn_limit? : Double = 1.0,
) -> SloTracker {
  {
    window: SloWindow::new(),
    target: clamp_probability(target),
    burn_limit: if burn_limit < 0.0 {
      0.0
    } else {
      burn_limit
    },
    periods: 0,
  }
}

///|
pub fn SloTracker::observe(self : SloTracker, result : DetectionResult) -> Unit {
  self.window.observe(result)
}

///|
pub fn SloTracker::close_period(self : SloTracker) -> SloReport {
  self.periods += 1
  evaluate_slo(self.window, target=self.target, burn_limit=self.burn_limit)
}

///|
pub fn SloTracker::periods(self : SloTracker) -> Int {
  self.periods
}

///|
pub fn SloTracker::window(self : SloTracker) -> SloWindow {
  self.window
}
