///|
pub struct ForecastPoint {
  prediction : Double
  lower : Double
  upper : Double
  residual : Double
}

///|
pub fn ForecastPoint::new(
  prediction : Double,
  residual : Double,
  uncertainty? : Double = 0.0,
) -> ForecastPoint {
  let width = if uncertainty < 0.0 { 0.0 } else { uncertainty }
  { prediction, lower: prediction - width, upper: prediction + width, residual }
}

///|
pub struct LinearForecaster {
  window : DoubleWindow
  horizon : Int
  uncertainty_multiplier : Double
}

///|
pub fn LinearForecaster::new(
  window_size? : Int = 16,
  horizon? : Int = 1,
  uncertainty_multiplier? : Double = 2.0,
) -> LinearForecaster {
  {
    window: DoubleWindow::new(if window_size < 2 { 2 } else { window_size }),
    horizon: if horizon < 1 {
      1
    } else {
      horizon
    },
    uncertainty_multiplier: if uncertainty_multiplier < 0.0 {
      0.0
    } else {
      uncertainty_multiplier
    },
  }
}

///|
pub fn LinearForecaster::fit(
  self : LinearForecaster,
  value : Double,
) -> ForecastPoint {
  let prediction = if self.window.length() < 2 {
    value
  } else {
    let slope = self.window.slope()
    match self.window.last() {
      None => value
      Some(last) => last + slope * self.horizon.to_double()
    }
  }
  let residual = if self.window.length() == 0 {
    0.0
  } else {
    value - self.window.mean()
  }
  let uncertainty = self.window.standard_deviation() *
    self.uncertainty_multiplier
  ignore(self.window.push(value))
  ForecastPoint::new(prediction, residual, uncertainty~)
}

///|
pub struct HoltForecaster {
  mut level : Double
  mut trend : Double
  alpha : Double
  beta : Double
  mut count : Int
}

///|
pub fn HoltForecaster::new(
  alpha? : Double = 0.2,
  beta? : Double = 0.1,
) -> HoltForecaster {
  {
    level: 0.0,
    trend: 0.0,
    alpha: clamp_probability(alpha),
    beta: clamp_probability(beta),
    count: 0,
  }
}

///|
pub fn HoltForecaster::update(
  self : HoltForecaster,
  value : Double,
  horizon? : Int = 1,
) -> ForecastPoint {
  if !is_finite(value) {
    return ForecastPoint::new(self.level, 0.0)
  }
  if self.count == 0 {
    self.level = value
    self.count = 1
    return ForecastPoint::new(value, 0.0)
  }
  let prediction = self.level + self.trend * horizon.to_double()
  let previous_level = self.level
  self.level = self.alpha * value +
    (1.0 - self.alpha) * (self.level + self.trend)
  self.trend = self.beta * (self.level - previous_level) +
    (1.0 - self.beta) * self.trend
  self.count += 1
  ForecastPoint::new(
    prediction,
    value - prediction,
    uncertainty=absolute(self.trend),
  )
}

///|
pub struct Ar1Forecaster {
  mut mean : Double
  mut covariance : Double
  mut variance : Double
  mut previous : Double
  mut count : Int
  forgetting : Double
}

///|
pub fn Ar1Forecaster::new(forgetting? : Double = 0.05) -> Ar1Forecaster {
  {
    mean: 0.0,
    covariance: 0.0,
    variance: 1.0,
    previous: 0.0,
    count: 0,
    forgetting: clamp_probability(forgetting),
  }
}

///|
pub fn Ar1Forecaster::update(
  self : Ar1Forecaster,
  value : Double,
) -> ForecastPoint {
  if self.count == 0 {
    self.mean = value
    self.previous = value
    self.count = 1
    return ForecastPoint::new(value, 0.0)
  }
  let denominator = if self.variance < 1.0e-12 { 1.0 } else { self.variance }
  let phi = self.covariance / denominator
  let prediction = self.mean + phi * (self.previous - self.mean)
  let residual = value - prediction
  let alpha = self.forgetting
  self.mean += alpha * (value - self.mean)
  self.covariance = (1.0 - alpha) * self.covariance +
    alpha * (self.previous - self.mean) * (value - self.mean)
  self.variance = (1.0 - alpha) * self.variance +
    alpha * (value - self.mean) * (value - self.mean)
  self.previous = value
  self.count += 1
  ForecastPoint::new(
    prediction,
    residual,
    uncertainty=self.variance.sqrt() * 2.0,
  )
}

///|
pub fn forecast_mae(
  actual : Array[Double],
  predicted : Array[Double],
) -> Double {
  let n = if actual.length() < predicted.length() {
    actual.length()
  } else {
    predicted.length()
  }
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<n {
    total += absolute(actual[i] - predicted[i])
  }
  total / n.to_double()
}

///|
pub fn forecast_rmse(
  actual : Array[Double],
  predicted : Array[Double],
) -> Double {
  let n = if actual.length() < predicted.length() {
    actual.length()
  } else {
    predicted.length()
  }
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<n {
    let difference = actual[i] - predicted[i]
    total += difference * difference
  }
  (total / n.to_double()).sqrt()
}

///|
pub fn forecast_mape(
  actual : Array[Double],
  predicted : Array[Double],
) -> Double {
  let n = if actual.length() < predicted.length() {
    actual.length()
  } else {
    predicted.length()
  }
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut count = 0
  for i in 0..<n {
    if absolute(actual[i]) > 1.0e-12 {
      total += absolute((actual[i] - predicted[i]) / actual[i])
      count += 1
    }
  }
  if count == 0 {
    0.0
  } else {
    total / count.to_double()
  }
}
