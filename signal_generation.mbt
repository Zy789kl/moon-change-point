///|
/// A deterministic pseudo-random source used by benchmarks and reproducible tests.
pub struct DeterministicRng {
  mut state : Int64
}

///|
pub fn DeterministicRng::new(
  seed? : Int64 = 88172645463393265L,
) -> DeterministicRng {
  { state: if seed == 0L { 88172645463393265L } else { seed } }
}

///|
pub fn DeterministicRng::next(self : DeterministicRng) -> Int64 {
  self.state = (self.state * 2862933555777941757L + 3037000493L) %
    9223372036854775783L
  if self.state < 0L {
    self.state = -self.state
  }
  self.state
}

///|
pub fn DeterministicRng::unit(self : DeterministicRng) -> Double {
  self.next().to_double() / 9223372036854775783.0
}

///|
pub fn DeterministicRng::symmetric(self : DeterministicRng) -> Double {
  self.unit() * 2.0 - 1.0
}

///|
pub fn DeterministicRng::normalish(
  self : DeterministicRng,
  amplitude? : Double = 1.0,
) -> Double {
  let first = if self.unit() < 1.0e-12 { 1.0e-12 } else { self.unit() }
  let second = self.unit()
  amplitude * (first + second - 1.0) * 1.7320508075688772
}

///|
pub(all) enum SignalPattern {
  Stable
  MeanShift
  VarianceShift
  Trend
  Spike
  MeanAndVarianceShift
}

///|
/// A scenario definition shared by tests, examples, and benchmarks.
pub struct SignalScenario {
  name : String
  length : Int
  change_at : Int
  baseline : Double
  shift : Double
  noise : Double
  post_noise : Double
  trend : Double
  pattern : SignalPattern
  seed : Int64
}

///|
pub fn SignalScenario::stable(
  length? : Int = 256,
  baseline? : Double = 0.0,
  noise? : Double = 0.1,
  seed? : Int64 = 17L,
) -> SignalScenario {
  {
    name: "stable",
    length: if length < 1 {
      1
    } else {
      length
    },
    change_at: length,
    baseline,
    shift: 0.0,
    noise: if noise < 0.0 {
      0.0
    } else {
      noise
    },
    post_noise: noise,
    trend: 0.0,
    pattern: Stable,
    seed,
  }
}

///|
pub fn SignalScenario::mean_shift(
  length? : Int = 256,
  change_at? : Int = 128,
  baseline? : Double = 0.0,
  shift? : Double = 2.0,
  noise? : Double = 0.1,
  seed? : Int64 = 17L,
) -> SignalScenario {
  {
    name: "mean-shift",
    length: if length < 1 {
      1
    } else {
      length
    },
    change_at: if change_at < 0 {
      0
    } else if change_at > length {
      length
    } else {
      change_at
    },
    baseline,
    shift,
    noise: if noise < 0.0 {
      0.0
    } else {
      noise
    },
    post_noise: noise,
    trend: 0.0,
    pattern: MeanShift,
    seed,
  }
}

///|
pub fn SignalScenario::variance_shift(
  length? : Int = 256,
  change_at? : Int = 128,
  baseline? : Double = 0.0,
  noise? : Double = 0.1,
  post_noise? : Double = 0.8,
  seed? : Int64 = 17L,
) -> SignalScenario {
  {
    name: "variance-shift",
    length: if length < 1 {
      1
    } else {
      length
    },
    change_at: if change_at < 0 {
      0
    } else if change_at > length {
      length
    } else {
      change_at
    },
    baseline,
    shift: 0.0,
    noise: if noise < 0.0 {
      0.0
    } else {
      noise
    },
    post_noise: if post_noise < 0.0 {
      0.0
    } else {
      post_noise
    },
    trend: 0.0,
    pattern: VarianceShift,
    seed,
  }
}

///|
pub fn SignalScenario::trend(
  length? : Int = 256,
  change_at? : Int = 64,
  baseline? : Double = 0.0,
  trend? : Double = 0.03,
  noise? : Double = 0.05,
  seed? : Int64 = 17L,
) -> SignalScenario {
  {
    name: "trend",
    length: if length < 1 {
      1
    } else {
      length
    },
    change_at: if change_at < 0 {
      0
    } else if change_at > length {
      length
    } else {
      change_at
    },
    baseline,
    shift: 0.0,
    noise: if noise < 0.0 {
      0.0
    } else {
      noise
    },
    post_noise: noise,
    trend,
    pattern: Trend,
    seed,
  }
}

///|
pub fn SignalScenario::spike(
  length? : Int = 256,
  spike_at? : Int = 128,
  baseline? : Double = 0.0,
  spike? : Double = 5.0,
  noise? : Double = 0.1,
  seed? : Int64 = 17L,
) -> SignalScenario {
  {
    name: "spike",
    length: if length < 1 {
      1
    } else {
      length
    },
    change_at: if spike_at < 0 {
      0
    } else if spike_at > length - 1 {
      length - 1
    } else {
      spike_at
    },
    baseline,
    shift: spike,
    noise: if noise < 0.0 {
      0.0
    } else {
      noise
    },
    post_noise: noise,
    trend: 0.0,
    pattern: Spike,
    seed,
  }
}

///|
pub fn SignalScenario::mean_and_variance(
  length? : Int = 256,
  change_at? : Int = 128,
  baseline? : Double = 0.0,
  shift? : Double = 2.0,
  noise? : Double = 0.1,
  post_noise? : Double = 0.6,
  seed? : Int64 = 17L,
) -> SignalScenario {
  {
    name: "mean-and-variance",
    length: if length < 1 {
      1
    } else {
      length
    },
    change_at: if change_at < 0 {
      0
    } else if change_at > length {
      length
    } else {
      change_at
    },
    baseline,
    shift,
    noise: if noise < 0.0 {
      0.0
    } else {
      noise
    },
    post_noise: if post_noise < 0.0 {
      0.0
    } else {
      post_noise
    },
    trend: 0.0,
    pattern: MeanAndVarianceShift,
    seed,
  }
}

///|
/// Generates a deterministic signal and its known change indices.
pub fn generate_signal(scenario : SignalScenario) -> Array[Double] {
  let rng = DeterministicRng::new(seed=scenario.seed)
  let result = Array::make(scenario.length, 0.0)
  for i in 0..<scenario.length {
    let post_change = i >= scenario.change_at
    let base = match scenario.pattern {
      Stable => scenario.baseline
      MeanShift =>
        if post_change {
          scenario.baseline + scenario.shift
        } else {
          scenario.baseline
        }
      VarianceShift => scenario.baseline
      Trend =>
        scenario.baseline +
        (if post_change {
          (i - scenario.change_at).to_double() * scenario.trend
        } else {
          0.0
        })
      Spike =>
        if i == scenario.change_at {
          scenario.baseline + scenario.shift
        } else {
          scenario.baseline
        }
      MeanAndVarianceShift =>
        if post_change {
          scenario.baseline + scenario.shift
        } else {
          scenario.baseline
        }
    }
    let amplitude = match scenario.pattern {
      VarianceShift =>
        if post_change {
          scenario.post_noise
        } else {
          scenario.noise
        }
      MeanAndVarianceShift =>
        if post_change {
          scenario.post_noise
        } else {
          scenario.noise
        }
      _ => scenario.noise
    }
    result[i] = base + rng.normalish(amplitude~)
  }
  result
}

///|
pub fn scenario_truth(scenario : SignalScenario) -> Array[Int] {
  match scenario.pattern {
    Stable => []
    Spike => [scenario.change_at]
    _ =>
      if scenario.change_at <= 0 || scenario.change_at >= scenario.length {
        []
      } else {
        [scenario.change_at]
      }
  }
}

///|
/// Converts a signal to timestamped points.
pub fn timestamped_signal(
  values : Array[Double],
  start? : Int64 = 0L,
  step? : Int64 = 1L,
) -> Array[SignalPoint] {
  let result : Array[SignalPoint] = []
  for i, value in values {
    result.push(
      SignalPoint::new(start + i.to_int64() * step, value, sequence=i),
    )
  }
  result
}

///|
/// Applies deterministic missingness without changing the length of the sample.
pub fn mask_every(
  values : Array[Double],
  period : Int,
  offset? : Int = 0,
) -> Array[Double] {
  let result : Array[Double] = []
  let safe_period = if period < 1 { 1 } else { period }
  for i, value in values {
    if (i - offset) % safe_period == 0 {
      result.push(0.0 / 0.0)
    } else {
      result.push(value)
    }
  }
  result
}

///|
/// Reorders every `period`-th point to model a small late-data burst.
pub fn reorder_periodic(
  points : Array[SignalPoint],
  period : Int,
) -> Array[SignalPoint] {
  let result : Array[SignalPoint] = []
  let safe_period = if period < 2 { 2 } else { period }
  let mut i = 0
  while i < points.length() {
    if i + 1 < points.length() && i % safe_period == 0 {
      result.push(points[i + 1])
      result.push(points[i])
      i += 2
    } else {
      result.push(points[i])
      i += 1
    }
  }
  result
}

///|
/// Returns a deterministic checksum useful for detecting accidental benchmark dead-code elimination.
pub fn signal_checksum(values : Array[Double]) -> Double {
  let mut checksum = 0.0
  for i, value in values {
    if is_finite(value) {
      checksum += (i + 1).to_double() * value
    }
  }
  checksum
}
