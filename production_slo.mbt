///|
/// SLO window kind for operational change detection services.
pub(all) enum ProductionSloWindowKind {
  ShortSloWindow
  LongSloWindow
  RollingSloWindow
}

///|
pub fn production_slo_window_name(kind : ProductionSloWindowKind) -> String {
  match kind {
    ShortSloWindow => "short"
    LongSloWindow => "long"
    RollingSloWindow => "rolling"
  }
}

///|
/// Objective for one service-level indicator.
pub struct ProductionSloObjective {
  name : String
  target : Double
  window : Int64
  burn_limit : Double
  kind : ProductionSloWindowKind
}

///|
pub fn ProductionSloObjective::new(
  name : String,
  target? : Double = 0.99,
  window? : Int64 = 3600L,
  burn_limit? : Double = 2.0,
  kind? : ProductionSloWindowKind = RollingSloWindow,
) -> ProductionSloObjective {
  {
    name,
    target: if target < 0.0 {
      0.0
    } else if target > 1.0 {
      1.0
    } else {
      target
    },
    window: if window < 1L {
      1L
    } else {
      window
    },
    burn_limit: if burn_limit < 0.0 {
      0.0
    } else {
      burn_limit
    },
    kind,
  }
}

///|
pub fn ProductionSloObjective::name(self : ProductionSloObjective) -> String {
  self.name
}

///|
pub fn ProductionSloObjective::target(self : ProductionSloObjective) -> Double {
  self.target
}

///|
pub fn ProductionSloObjective::window(self : ProductionSloObjective) -> Int64 {
  self.window
}

///|
pub fn ProductionSloObjective::burn_limit(
  self : ProductionSloObjective,
) -> Double {
  self.burn_limit
}

///|
pub fn ProductionSloObjective::kind(
  self : ProductionSloObjective,
) -> ProductionSloWindowKind {
  self.kind
}

///|
pub fn ProductionSloObjective::error_budget(
  self : ProductionSloObjective,
) -> Double {
  1.0 - self.target
}

///|
pub fn ProductionSloObjective::summary(self : ProductionSloObjective) -> String {
  self.name +
  ":target=" +
  self.target.to_string() +
  ",window=" +
  self.window.to_string() +
  ",burn_limit=" +
  self.burn_limit.to_string() +
  ",kind=" +
  production_slo_window_name(self.kind)
}

///|
/// Current burn and compliance state for one SLO.
pub struct ProductionSloReport {
  objective : ProductionSloObjective
  total : Int
  good : Int
  bad : Int
  compliance : Double
  burn_rate : Double
  remaining_budget : Double
  breached : Bool
}

///|
pub fn ProductionSloReport::objective(
  self : ProductionSloReport,
) -> ProductionSloObjective {
  self.objective
}

///|
pub fn ProductionSloReport::total(self : ProductionSloReport) -> Int {
  self.total
}

///|
pub fn ProductionSloReport::good(self : ProductionSloReport) -> Int {
  self.good
}

///|
pub fn ProductionSloReport::bad(self : ProductionSloReport) -> Int {
  self.bad
}

///|
pub fn ProductionSloReport::compliance(self : ProductionSloReport) -> Double {
  self.compliance
}

///|
pub fn ProductionSloReport::burn_rate(self : ProductionSloReport) -> Double {
  self.burn_rate
}

///|
pub fn ProductionSloReport::remaining_budget(
  self : ProductionSloReport,
) -> Double {
  self.remaining_budget
}

///|
pub fn ProductionSloReport::breached(self : ProductionSloReport) -> Bool {
  self.breached
}

///|
pub fn ProductionSloReport::summary(self : ProductionSloReport) -> String {
  self.objective.name() +
  ":compliance=" +
  self.compliance.to_string() +
  ",burn=" +
  self.burn_rate.to_string() +
  ",budget=" +
  self.remaining_budget.to_string() +
  ",breached=" +
  self.breached.to_string()
}

///|
/// Mutable SLO tracker fed by accepted/rejected monitor outcomes.
pub struct ProductionSloTracker {
  objective : ProductionSloObjective
  mut total : Int
  mut good : Int
  mut bad : Int
  mut window_start : Int64?
}

///|
pub fn ProductionSloTracker::new(
  objective : ProductionSloObjective,
) -> ProductionSloTracker {
  { objective, total: 0, good: 0, bad: 0, window_start: None }
}

///|
pub fn ProductionSloTracker::objective(
  self : ProductionSloTracker,
) -> ProductionSloObjective {
  self.objective
}

///|
pub fn ProductionSloTracker::total(self : ProductionSloTracker) -> Int {
  self.total
}

///|
pub fn ProductionSloTracker::good(self : ProductionSloTracker) -> Int {
  self.good
}

///|
pub fn ProductionSloTracker::bad(self : ProductionSloTracker) -> Int {
  self.bad
}

///|
pub fn ProductionSloTracker::observe(
  self : ProductionSloTracker,
  timestamp : Int64,
  good : Bool,
) -> Unit {
  match self.window_start {
    None => self.window_start = Some(timestamp)
    Some(start) =>
      if timestamp - start >= self.objective.window() {
        self.window_start = Some(timestamp)
        self.total = 0
        self.good = 0
        self.bad = 0
      }
  }
  self.total += 1
  if good {
    self.good += 1
  } else {
    self.bad += 1
  }
}

///|
pub fn ProductionSloTracker::observe_event(
  self : ProductionSloTracker,
  timestamp : Int64,
  event : ProductionMonitorEvent,
) -> Unit {
  self.observe(timestamp, !event.result().changed)
}

///|
pub fn ProductionSloTracker::report(
  self : ProductionSloTracker,
) -> ProductionSloReport {
  let compliance = if self.total == 0 {
    1.0
  } else {
    self.good.to_double() / self.total.to_double()
  }
  let budget = self.objective.error_budget()
  let error_rate = 1.0 - compliance
  let burn = if budget <= 1.0e-12 {
    if error_rate > 0.0 {
      1.0e6
    } else {
      0.0
    }
  } else {
    error_rate / budget
  }
  {
    objective: self.objective,
    total: self.total,
    good: self.good,
    bad: self.bad,
    compliance,
    burn_rate: burn,
    remaining_budget: clamp_probability(
      1.0 - error_rate / (if budget <= 1.0e-12 { 1.0 } else { budget }),
    ),
    breached: compliance < self.objective.target ||
    burn > self.objective.burn_limit,
  }
}

///|
pub fn ProductionSloTracker::reset(self : ProductionSloTracker) -> Unit {
  self.total = 0
  self.good = 0
  self.bad = 0
  self.window_start = None
}

///|
pub fn production_slo_reports_markdown(
  reports : Array[ProductionSloReport],
) -> String {
  let mut output = "| SLO | total | good | bad | compliance | burn rate | budget | breached |\n|---|---:|---:|---:|---:|---:|---:|---|\n"
  for report in reports {
    output = output +
      "| " +
      report.objective().name() +
      " | " +
      report.total().to_string() +
      " | " +
      report.good().to_string() +
      " | " +
      report.bad().to_string() +
      " | " +
      report.compliance().to_string() +
      " | " +
      report.burn_rate().to_string() +
      " | " +
      report.remaining_budget().to_string() +
      " | " +
      report.breached().to_string() +
      " |\n"
  }
  output
}
