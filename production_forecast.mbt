///|
/// Forecast family supported by the production model wrapper.
pub(all) enum ProductionForecastKind {
  LastValueForecast
  MeanForecast
  HoltForecast
  SeasonalNaiveForecast
  HoltWintersForecast
}

///|
/// Forecast interval with explicit coverage and residual diagnostics.
pub struct ProductionForecastInterval {
  timestamp : Int64
  prediction : Double
  lower : Double
  upper : Double
  confidence : Double
  horizon : Int
  model : ProductionForecastKind
}

///|
pub fn ProductionForecastInterval::new(
  timestamp : Int64,
  prediction : Double,
  uncertainty : Double,
  confidence? : Double = 0.95,
  horizon? : Int = 1,
  model? : ProductionForecastKind = LastValueForecast,
) -> ProductionForecastInterval {
  let width = if !is_finite(uncertainty) || uncertainty < 0.0 {
    0.0
  } else {
    uncertainty
  }
  {
    timestamp,
    prediction,
    lower: prediction - width,
    upper: prediction + width,
    confidence: clamp_probability(confidence),
    horizon: if horizon < 1 {
      1
    } else {
      horizon
    },
    model,
  }
}

///|
pub fn ProductionForecastInterval::timestamp(
  self : ProductionForecastInterval,
) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionForecastInterval::prediction(
  self : ProductionForecastInterval,
) -> Double {
  self.prediction
}

///|
pub fn ProductionForecastInterval::lower(
  self : ProductionForecastInterval,
) -> Double {
  self.lower
}

///|
pub fn ProductionForecastInterval::upper(
  self : ProductionForecastInterval,
) -> Double {
  self.upper
}

///|
pub fn ProductionForecastInterval::confidence(
  self : ProductionForecastInterval,
) -> Double {
  self.confidence
}

///|
pub fn ProductionForecastInterval::horizon(
  self : ProductionForecastInterval,
) -> Int {
  self.horizon
}

///|
pub fn ProductionForecastInterval::width(
  self : ProductionForecastInterval,
) -> Double {
  self.upper - self.lower
}

///|
pub fn production_forecast_kind_name(kind : ProductionForecastKind) -> String {
  match kind {
    LastValueForecast => "last-value"
    MeanForecast => "mean"
    HoltForecast => "holt"
    SeasonalNaiveForecast => "seasonal-naive"
    HoltWintersForecast => "holt-winters"
  }
}

///|
/// An exponentially weighted residual scale used to construct robust intervals.
pub struct ProductionResidualScale {
  alpha : Double
  mut center : Double
  mut deviation : Double
  mut count : Int
  mut missing : Int
}

///|
pub fn ProductionResidualScale::new(
  alpha? : Double = 0.1,
) -> ProductionResidualScale {
  {
    alpha: if alpha <= 0.0 {
      0.1
    } else {
      clamp_probability(alpha)
    },
    center: 0.0,
    deviation: 0.0,
    count: 0,
    missing: 0,
  }
}

///|
pub fn ProductionResidualScale::update(
  self : ProductionResidualScale,
  residual : Double,
) -> Double {
  if !is_finite(residual) {
    self.missing += 1
    return self.deviation
  }
  if self.count == 0 {
    self.center = residual
    self.deviation = 0.0
    self.count = 1
    return 0.0
  }
  let previous = self.center
  self.center += self.alpha * (residual - self.center)
  self.deviation += self.alpha *
    (absolute(residual - previous) - self.deviation)
  self.count += 1
  self.deviation
}

///|
pub fn ProductionResidualScale::center(
  self : ProductionResidualScale,
) -> Double {
  self.center
}

///|
pub fn ProductionResidualScale::deviation(
  self : ProductionResidualScale,
) -> Double {
  self.deviation
}

///|
pub fn ProductionResidualScale::count(self : ProductionResidualScale) -> Int {
  self.count
}

///|
pub fn ProductionResidualScale::missing(self : ProductionResidualScale) -> Int {
  self.missing
}

///|
pub fn ProductionResidualScale::uncertainty(
  self : ProductionResidualScale,
  confidence? : Double = 0.95,
) -> Double {
  let coverage = clamp_probability(confidence)
  let multiplier = if coverage >= 0.99 {
    2.58
  } else if coverage >= 0.95 {
    1.96
  } else if coverage >= 0.90 {
    1.65
  } else {
    1.0
  }
  self.deviation * multiplier
}

///|
/// Robust quantile state for models with non-Gaussian residuals.
pub struct ProductionQuantileState {
  capacity : Int
  residuals : Array[Double]
  mut cursor : Int
}

///|
pub fn ProductionQuantileState::new(
  capacity? : Int = 256,
) -> ProductionQuantileState {
  {
    capacity: if capacity < 4 {
      4
    } else {
      capacity
    },
    residuals: [],
    cursor: 0,
  }
}

///|
pub fn ProductionQuantileState::push(
  self : ProductionQuantileState,
  residual : Double,
) -> Unit {
  if !is_finite(residual) {
    return
  }
  if self.residuals.length() < self.capacity {
    self.residuals.push(residual)
  } else {
    self.residuals[self.cursor] = residual
    self.cursor = (self.cursor + 1) % self.capacity
  }
}

///|
pub fn ProductionQuantileState::count(self : ProductionQuantileState) -> Int {
  self.residuals.length()
}

///|
pub fn ProductionQuantileState::quantile(
  self : ProductionQuantileState,
  probability : Double,
) -> Double {
  quantile(self.residuals, probability)
}

///|
pub fn ProductionQuantileState::absolute_quantile(
  self : ProductionQuantileState,
  probability : Double,
) -> Double {
  let values : Array[Double] = []
  for residual in self.residuals {
    values.push(absolute(residual))
  }
  quantile(values, probability)
}

///|
pub fn ProductionQuantileState::middle_spread(
  self : ProductionQuantileState,
) -> Double {
  self.quantile(0.9) - self.quantile(0.1)
}

///|
/// Additive Holt-Winters state for periodic production telemetry.
pub struct ProductionHoltWinters {
  period : Int
  alpha : Double
  beta : Double
  gamma : Double
  levels : Array[Double]
  mut level : Double
  mut trend : Double
  mut count : Int
  mut index : Int
  mut initialized : Bool
  residuals : ProductionResidualScale
}

///|
pub fn ProductionHoltWinters::new(
  period? : Int = 24,
  alpha? : Double = 0.2,
  beta? : Double = 0.05,
  gamma? : Double = 0.1,
) -> ProductionHoltWinters {
  let safe_period = if period < 1 { 1 } else { period }
  {
    period: safe_period,
    alpha: clamp_probability(alpha),
    beta: clamp_probability(beta),
    gamma: clamp_probability(gamma),
    levels: Array::make(safe_period, 0.0),
    level: 0.0,
    trend: 0.0,
    count: 0,
    index: 0,
    initialized: false,
    residuals: ProductionResidualScale::new(),
  }
}

///|
pub fn ProductionHoltWinters::period(self : ProductionHoltWinters) -> Int {
  self.period
}

///|
pub fn ProductionHoltWinters::count(self : ProductionHoltWinters) -> Int {
  self.count
}

///|
pub fn ProductionHoltWinters::level(self : ProductionHoltWinters) -> Double {
  self.level
}

///|
pub fn ProductionHoltWinters::trend(self : ProductionHoltWinters) -> Double {
  self.trend
}

///|
pub fn ProductionHoltWinters::seasonals(
  self : ProductionHoltWinters,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.levels {
    result.push(value)
  }
  result
}

///|
fn ProductionHoltWinters::seasonal_at(
  self : ProductionHoltWinters,
  index : Int,
) -> Double {
  self.levels[(index % self.period + self.period) % self.period]
}

///|
pub fn ProductionHoltWinters::predict(
  self : ProductionHoltWinters,
  horizon? : Int = 1,
) -> Double {
  let safe_horizon = if horizon < 1 { 1 } else { horizon }
  if !self.initialized {
    self.level
  } else {
    self.level +
    self.trend * safe_horizon.to_double() +
    self.seasonal_at(self.index + safe_horizon - 1)
  }
}

///|
pub fn ProductionHoltWinters::predict_interval(
  self : ProductionHoltWinters,
  timestamp : Int64,
  horizon? : Int = 1,
  confidence? : Double = 0.95,
) -> ProductionForecastInterval {
  let safe_horizon = if horizon < 1 { 1 } else { horizon }
  let prediction = self.predict(horizon=safe_horizon)
  let uncertainty = self.residuals.uncertainty(confidence~) *
    safe_horizon.to_double().sqrt()
  ProductionForecastInterval::new(
    timestamp,
    prediction,
    uncertainty,
    confidence~,
    horizon=safe_horizon,
    model=HoltWintersForecast,
  )
}

///|
pub fn ProductionHoltWinters::update(
  self : ProductionHoltWinters,
  value : Double,
) -> ForecastPoint {
  if !is_finite(value) {
    return ForecastPoint::new(
      self.predict(),
      0.0,
      uncertainty=self.residuals.uncertainty(),
    )
  }
  let position = self.index % self.period
  if !self.initialized {
    self.level = value
    self.levels[position] = 0.0
    self.index += 1
    self.count += 1
    if self.count >= self.period {
      self.initialized = true
    }
    return ForecastPoint::new(value, 0.0)
  }
  let seasonal = self.levels[position]
  let prediction = self.level + self.trend + seasonal
  let previous_level = self.level
  let new_level = self.alpha * (value - seasonal) +
    (1.0 - self.alpha) * (self.level + self.trend)
  self.trend = self.beta * (new_level - previous_level) +
    (1.0 - self.beta) * self.trend
  self.level = new_level
  self.levels[position] = self.gamma * (value - new_level) +
    (1.0 - self.gamma) * seasonal
  self.index += 1
  self.count += 1
  let residual = value - prediction
  let scale = self.residuals.update(residual)
  ForecastPoint::new(prediction, residual, uncertainty=scale * 1.96)
}

///|
/// A model-agnostic production forecaster with a rolling residual envelope.
pub struct ProductionForecaster {
  kind : ProductionForecastKind
  period : Int
  horizon : Int
  window : DoubleWindow
  holt : HoltForecaster
  seasonal : ProductionHoltWinters
  residuals : ProductionQuantileState
  mut count : Int
  mut missing : Int
}

///|
pub fn ProductionForecaster::new(
  kind? : ProductionForecastKind = HoltForecast,
  window_size? : Int = 32,
  period? : Int = 24,
  horizon? : Int = 1,
) -> ProductionForecaster {
  {
    kind,
    period: if period < 1 {
      1
    } else {
      period
    },
    horizon: if horizon < 1 {
      1
    } else {
      horizon
    },
    window: DoubleWindow::new(if window_size < 2 { 2 } else { window_size }),
    holt: HoltForecaster::new(),
    seasonal: ProductionHoltWinters::new(
      period=if period < 1 { 1 } else { period },
    ),
    residuals: ProductionQuantileState::new(),
    count: 0,
    missing: 0,
  }
}

///|
pub fn ProductionForecaster::kind(
  self : ProductionForecaster,
) -> ProductionForecastKind {
  self.kind
}

///|
pub fn ProductionForecaster::count(self : ProductionForecaster) -> Int {
  self.count
}

///|
pub fn ProductionForecaster::missing(self : ProductionForecaster) -> Int {
  self.missing
}

///|
fn ProductionForecaster::point_prediction(
  self : ProductionForecaster,
  value : Double,
) -> ForecastPoint {
  match self.kind {
    LastValueForecast => {
      let prediction = match self.window.last() {
        None => value
        Some(last) => last
      }
      ForecastPoint::new(prediction, value - prediction)
    }
    MeanForecast => {
      let prediction = if self.window.length() == 0 {
        value
      } else {
        self.window.mean()
      }
      ForecastPoint::new(prediction, value - prediction)
    }
    HoltForecast => self.holt.update(value, horizon=self.horizon)
    SeasonalNaiveForecast => {
      let prediction = match
        self.window.get(self.window.length() - self.period) {
        None =>
          if self.window.length() == 0 {
            value
          } else {
            self.window.mean()
          }
        Some(previous) => previous
      }
      ForecastPoint::new(prediction, value - prediction)
    }
    HoltWintersForecast => self.seasonal.update(value)
  }
}

///|
pub fn ProductionForecaster::update(
  self : ProductionForecaster,
  value : Double,
) -> ProductionForecastInterval {
  if !is_finite(value) {
    self.missing += 1
    return ProductionForecastInterval::new(
      self.count.to_int64(),
      self.predict(),
      self.uncertainty(),
      model=self.kind,
      horizon=self.horizon,
    )
  }
  let point = self.point_prediction(value)
  let prediction = point.prediction
  let residual = value - prediction
  self.residuals.push(residual)
  ignore(self.window.push(value))
  self.count += 1
  ProductionForecastInterval::new(
    self.count.to_int64(),
    prediction,
    self.uncertainty(),
    model=self.kind,
    horizon=self.horizon,
  )
}

///|
pub fn ProductionForecaster::predict(self : ProductionForecaster) -> Double {
  match self.kind {
    LastValueForecast =>
      match self.window.last() {
        None => 0.0
        Some(value) => value
      }
    MeanForecast => self.window.mean()
    HoltForecast => self.holt.level + self.holt.trend * self.horizon.to_double()
    SeasonalNaiveForecast =>
      match self.window.get(self.window.length() - self.period) {
        None => self.window.mean()
        Some(value) => value
      }
    HoltWintersForecast => self.seasonal.predict(horizon=self.horizon)
  }
}

///|
pub fn ProductionForecaster::uncertainty(
  self : ProductionForecaster,
  confidence? : Double = 0.95,
) -> Double {
  if self.residuals.count() < 4 {
    self.window.standard_deviation() * 1.96
  } else {
    self.residuals.absolute_quantile(clamp_probability(confidence))
  }
}

///|
pub fn ProductionForecaster::forecast(
  self : ProductionForecaster,
  start_timestamp : Int64,
  step : Int64,
  horizon? : Int = 1,
  confidence? : Double = 0.95,
) -> Array[ProductionForecastInterval] {
  let result : Array[ProductionForecastInterval] = []
  let safe_horizon = if horizon < 1 { 1 } else { horizon }
  for i in 1..<=safe_horizon {
    let prediction = match self.kind {
      LastValueForecast => self.predict()
      MeanForecast => self.predict()
      HoltForecast =>
        match self.holt.update(0.0, horizon=i) {
          point => point.prediction
        }
      SeasonalNaiveForecast => self.predict()
      HoltWintersForecast => self.seasonal.predict(horizon=i)
    }
    result.push(
      ProductionForecastInterval::new(
        start_timestamp + step * i.to_int64(),
        prediction,
        self.uncertainty(confidence~),
        confidence~,
        horizon=i,
        model=self.kind,
      ),
    )
  }
  result
}

///|
/// Compares several deterministic forecast families on a holdout suffix.
pub struct ProductionForecastScore {
  model : ProductionForecastKind
  mae : Double
  rmse : Double
  bias : Double
  coverage : Double
}

///|
pub fn ProductionForecastScore::model(
  self : ProductionForecastScore,
) -> ProductionForecastKind {
  self.model
}

///|
pub fn ProductionForecastScore::mae(self : ProductionForecastScore) -> Double {
  self.mae
}

///|
pub fn ProductionForecastScore::rmse(self : ProductionForecastScore) -> Double {
  self.rmse
}

///|
pub fn ProductionForecastScore::bias(self : ProductionForecastScore) -> Double {
  self.bias
}

///|
pub fn ProductionForecastScore::coverage(
  self : ProductionForecastScore,
) -> Double {
  self.coverage
}

///|
pub fn production_forecast_score(
  actual : Array[Double],
  predictions : Array[ProductionForecastInterval],
) -> ProductionForecastScore {
  let n = if actual.length() < predictions.length() {
    actual.length()
  } else {
    predictions.length()
  }
  if n == 0 {
    return {
      model: LastValueForecast,
      mae: 0.0,
      rmse: 0.0,
      bias: 0.0,
      coverage: 0.0,
    }
  }
  let errors : Array[Double] = []
  let mut covered = 0
  for i in 0..<n {
    let error = actual[i] - predictions[i].prediction
    errors.push(error)
    if actual[i] >= predictions[i].lower && actual[i] <= predictions[i].upper {
      covered += 1
    }
  }
  let mut squared = 0.0
  let mut absolute_total = 0.0
  let mut bias = 0.0
  for error in errors {
    squared += error * error
    absolute_total += absolute(error)
    bias += error
  }
  {
    model: predictions[0].model,
    mae: absolute_total / n.to_double(),
    rmse: (squared / n.to_double()).sqrt(),
    bias: bias / n.to_double(),
    coverage: covered.to_double() / n.to_double(),
  }
}

///|
pub fn production_forecast_scores_markdown(
  scores : Array[ProductionForecastScore],
) -> String {
  let mut output = "| model | MAE | RMSE | bias | coverage |\n|---|---:|---:|---:|---:|\n"
  for score in scores {
    output = output +
      "| " +
      production_forecast_kind_name(score.model()) +
      " | " +
      score.mae().to_string() +
      " | " +
      score.rmse().to_string() +
      " | " +
      score.bias().to_string() +
      " | " +
      score.coverage().to_string() +
      " |\n"
  }
  output
}
