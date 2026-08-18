///|
/// A debouncer that requires several consecutive positive observations.
pub struct ConsecutiveRule {
  required : Int
  mut hits : Int
  mut misses : Int
}

///|
pub fn ConsecutiveRule::new(required? : Int = 3) -> ConsecutiveRule {
  { required: if required < 1 { 1 } else { required }, hits: 0, misses: 0 }
}

///|
pub fn ConsecutiveRule::push(self : ConsecutiveRule, positive : Bool) -> Bool {
  if positive {
    self.hits += 1
    self.misses = 0
  } else {
    self.hits = 0
    self.misses += 1
  }
  if self.hits >= self.required {
    self.hits = 0
    true
  } else {
    false
  }
}

///|
pub fn ConsecutiveRule::hits(self : ConsecutiveRule) -> Int {
  self.hits
}

///|
/// Hysteresis prevents alert flapping around a single threshold.
pub struct HysteresisRule {
  enter_threshold : Double
  exit_threshold : Double
  mut active : Bool
}

///|
pub fn HysteresisRule::new(
  enter_threshold? : Double = 1.0,
  exit_threshold? : Double = 0.5,
) -> HysteresisRule {
  let enter = if enter_threshold < 0.0 { 0.0 } else { enter_threshold }
  {
    enter_threshold: enter,
    exit_threshold: if exit_threshold < 0.0 {
      0.0
    } else if exit_threshold > enter {
      enter
    } else {
      exit_threshold
    },
    active: false,
  }
}

///|
pub fn HysteresisRule::push(self : HysteresisRule, score : Double) -> Bool {
  if self.active {
    if score <= self.exit_threshold {
      self.active = false
    }
  } else if score >= self.enter_threshold {
    self.active = true
  }
  self.active
}

///|
pub fn HysteresisRule::active(self : HysteresisRule) -> Bool {
  self.active
}

///|
pub struct VoteRule {
  required : Int
  window : Array[Bool]
  size : Int
}

///|
pub fn VoteRule::new(size? : Int = 5, required? : Int = 3) -> VoteRule {
  let safe_size = if size < 1 { 1 } else { size }
  {
    required: if required < 1 {
      1
    } else if required > safe_size {
      safe_size
    } else {
      required
    },
    window: [],
    size: safe_size,
  }
}

///|
pub fn VoteRule::push(self : VoteRule, positive : Bool) -> Bool {
  self.window.push(positive)
  if self.window.length() > self.size {
    ignore(self.window.remove(0))
  }
  let mut votes = 0
  for item in self.window {
    if item {
      votes += 1
    }
  }
  votes >= self.required
}

///|
pub fn VoteRule::votes(self : VoteRule) -> Int {
  let mut count = 0
  for item in self.window {
    if item {
      count += 1
    }
  }
  count
}

///|
pub struct AlertBudget {
  capacity : Double
  refill : Double
  mut tokens : Double
  mut suppressed : Int
}

///|
pub fn AlertBudget::new(
  capacity? : Int = 5,
  refill? : Double = 1.0,
) -> AlertBudget {
  let safe_capacity = if capacity < 1 { 1 } else { capacity }
  {
    capacity: safe_capacity.to_double(),
    refill: if refill < 0.0 {
      0.0
    } else {
      refill
    },
    tokens: safe_capacity.to_double(),
    suppressed: 0,
  }
}

///|
pub fn AlertBudget::tick(self : AlertBudget) -> Unit {
  self.tokens = if self.tokens + self.refill > self.capacity {
    self.capacity
  } else {
    self.tokens + self.refill
  }
}

///|
pub fn AlertBudget::allow(self : AlertBudget) -> Bool {
  if self.tokens >= 1.0 {
    self.tokens -= 1.0
    true
  } else {
    self.suppressed += 1
    false
  }
}

///|
pub fn AlertBudget::suppressed(self : AlertBudget) -> Int {
  self.suppressed
}
