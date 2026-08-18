///|
pub struct ReservoirSample {
  capacity : Int
  values : Array[Double]
  mut seen : Int
  rng : DeterministicRng
}

///|
pub fn ReservoirSample::new(
  capacity : Int,
  seed? : Int64 = 29L,
) -> ReservoirSample {
  {
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    values: [],
    seen: 0,
    rng: DeterministicRng::new(seed~),
  }
}

///|
pub fn ReservoirSample::push(self : ReservoirSample, value : Double) -> Unit {
  if !is_finite(value) {
    return
  }
  self.seen += 1
  if self.values.length() < self.capacity {
    self.values.push(value)
  } else {
    let index = (self.rng.next() % self.seen.to_int64()).to_int()
    if index < self.capacity {
      self.values[index] = value
    }
  }
}

///|
pub fn ReservoirSample::seen(self : ReservoirSample) -> Int {
  self.seen
}

///|
pub fn ReservoirSample::values(self : ReservoirSample) -> Array[Double] {
  sorted_copy(self.values)
}

///|
pub struct BootstrapEstimate {
  mean : Double
  lower : Double
  upper : Double
  standard_error : Double
  replicates : Int
}

///|
pub fn bootstrap_mean(
  values : Array[Double],
  replicates? : Int = 100,
  seed? : Int64 = 31L,
) -> BootstrapEstimate {
  if values.length() == 0 {
    return {
      mean: 0.0,
      lower: 0.0,
      upper: 0.0,
      standard_error: 0.0,
      replicates: 0,
    }
  }
  let rng = DeterministicRng::new(seed~)
  let size = if replicates < 1 { 1 } else { replicates }
  let estimates : Array[Double] = []
  for _ in 0..<size {
    let sample : Array[Double] = []
    for _ in 0..<values.length() {
      sample.push(values[(rng.next() % values.length().to_int64()).to_int()])
    }
    estimates.push(mean(sample))
  }
  let center = mean(estimates)
  {
    mean: center,
    lower: quantile(estimates, 0.025),
    upper: quantile(estimates, 0.975),
    standard_error: standard_deviation(estimates),
    replicates: size,
  }
}

///|
pub fn bootstrap_change_score(
  left : Array[Double],
  right : Array[Double],
  replicates? : Int = 100,
  seed? : Int64 = 37L,
) -> BootstrapEstimate {
  if left.length() == 0 || right.length() == 0 {
    return {
      mean: 0.0,
      lower: 0.0,
      upper: 0.0,
      standard_error: 0.0,
      replicates: 0,
    }
  }
  let rng = DeterministicRng::new(seed~)
  let size = if replicates < 1 { 1 } else { replicates }
  let scores : Array[Double] = []
  for _ in 0..<size {
    let a : Array[Double] = []
    let b : Array[Double] = []
    for _ in 0..<left.length() {
      a.push(left[(rng.next() % left.length().to_int64()).to_int()])
    }
    for _ in 0..<right.length() {
      b.push(right[(rng.next() % right.length().to_int64()).to_int()])
    }
    scores.push(distribution_change_score(a, b))
  }
  {
    mean: mean(scores),
    lower: quantile(scores, 0.025),
    upper: quantile(scores, 0.975),
    standard_error: standard_deviation(scores),
    replicates: size,
  }
}

///|
pub fn split_train_test(
  values : Array[Double],
  train_fraction? : Double = 0.8,
) -> (Array[Double], Array[Double]) {
  let split = (values.length().to_double() * clamp_probability(train_fraction)).to_int()
  let train : Array[Double] = []
  let holdout : Array[Double] = []
  for i, value in values {
    if i < split {
      train.push(value)
    } else {
      holdout.push(value)
    }
  }
  (train, holdout)
}

///|
pub fn rolling_origins(
  length : Int,
  train_size : Int,
  horizon : Int,
  step? : Int = 1,
) -> Array[SegmentRange] {
  let result : Array[SegmentRange] = []
  let safe_step = if step < 1 { 1 } else { step }
  let mut origin = if train_size < 1 { 1 } else { train_size }
  while origin + horizon <= length {
    result.push({ start: origin - train_size, end: origin + horizon })
    origin += safe_step
  }
  result
}

///|
pub fn stratified_counts(values : Array[Double], bins : Int) -> Array[Int] {
  let result = Array::make(if bins < 1 { 1 } else { bins }, 0)
  if values.length() == 0 {
    return result
  }
  let low = array_minimum(values)
  let high = array_maximum(values)
  let range = high - low
  for value in values {
    let index = if range <= 1.0e-12 {
      0
    } else {
      ((value - low) / range * result.length().to_double()).to_int()
    }
    let safe = if index >= result.length() {
      result.length() - 1
    } else if index < 0 {
      0
    } else {
      index
    }
    result[safe] += 1
  }
  result
}
