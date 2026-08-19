///|
/// Feature family exposed by the production feature pipeline.
pub(all) enum ProductionFeatureKind {
  LevelFeature
  SpreadFeature
  TrendFeature
  VolatilityFeature
  SkewFeature
  KurtosisFeature
  AutocorrelationFeature
  DifferenceFeature
  QuantileFeature
  DistributionEntropyFeature
  MissingRatioFeature
  OutlierRatioFeature
  SeasonalStrengthFeature
}

///|
pub fn production_feature_kind_name(kind : ProductionFeatureKind) -> String {
  match kind {
    LevelFeature => "level"
    SpreadFeature => "spread"
    TrendFeature => "trend"
    VolatilityFeature => "volatility"
    SkewFeature => "skew"
    KurtosisFeature => "kurtosis"
    AutocorrelationFeature => "autocorrelation"
    DifferenceFeature => "difference"
    QuantileFeature => "quantile"
    DistributionEntropyFeature => "distribution-entropy"
    MissingRatioFeature => "missing-ratio"
    OutlierRatioFeature => "outlier-ratio"
    SeasonalStrengthFeature => "seasonal-strength"
  }
}

///|
/// One named feature value with quality and provenance metadata.
pub struct ProductionFeature {
  name : String
  kind : ProductionFeatureKind
  value : Double
  valid : Bool
  sample_count : Int
  source_window : Int
}

///|
pub fn ProductionFeature::new(
  kind : ProductionFeatureKind,
  value : Double,
  sample_count : Int,
  source_window : Int,
) -> ProductionFeature {
  {
    name: production_feature_kind_name(kind),
    kind,
    value: if is_finite(value) {
      value
    } else {
      0.0
    },
    valid: is_finite(value),
    sample_count: if sample_count < 0 {
      0
    } else {
      sample_count
    },
    source_window: if source_window < 0 {
      0
    } else {
      source_window
    },
  }
}

///|
pub fn ProductionFeature::name(self : ProductionFeature) -> String {
  self.name
}

///|
pub fn ProductionFeature::kind(
  self : ProductionFeature,
) -> ProductionFeatureKind {
  self.kind
}

///|
pub fn ProductionFeature::value(self : ProductionFeature) -> Double {
  self.value
}

///|
pub fn ProductionFeature::valid(self : ProductionFeature) -> Bool {
  self.valid
}

///|
pub fn ProductionFeature::sample_count(self : ProductionFeature) -> Int {
  self.sample_count
}

///|
pub fn ProductionFeature::source_window(self : ProductionFeature) -> Int {
  self.source_window
}

///|
/// A fixed-order feature vector suitable for a model or report.
pub struct ProductionFeatureVector {
  features : Array[ProductionFeature]
  values : Array[Double]
  valid_count : Int
  missing_count : Int
}

///|
pub fn ProductionFeatureVector::new(
  features : Array[ProductionFeature],
) -> ProductionFeatureVector {
  let values : Array[Double] = []
  let mut valid_count = 0
  let mut missing_count = 0
  for feature in features {
    values.push(feature.value())
    if feature.valid() {
      valid_count += 1
    } else {
      missing_count += 1
    }
  }
  { features, values, valid_count, missing_count }
}

///|
pub fn ProductionFeatureVector::features(
  self : ProductionFeatureVector,
) -> Array[ProductionFeature] {
  let result : Array[ProductionFeature] = []
  for feature in self.features {
    result.push(feature)
  }
  result
}

///|
pub fn ProductionFeatureVector::values(
  self : ProductionFeatureVector,
) -> Array[Double] {
  let result : Array[Double] = []
  for value in self.values {
    result.push(value)
  }
  result
}

///|
pub fn ProductionFeatureVector::valid_count(
  self : ProductionFeatureVector,
) -> Int {
  self.valid_count
}

///|
pub fn ProductionFeatureVector::missing_count(
  self : ProductionFeatureVector,
) -> Int {
  self.missing_count
}

///|
pub fn ProductionFeatureVector::valid_ratio(
  self : ProductionFeatureVector,
) -> Double {
  if self.features.length() == 0 {
    1.0
  } else {
    self.valid_count.to_double() / self.features.length().to_double()
  }
}

///|
pub fn ProductionFeatureVector::get(
  self : ProductionFeatureVector,
  name : String,
) -> ProductionFeature? {
  for feature in self.features {
    if feature.name() == name {
      return Some(feature)
    }
  }
  None
}

///|
pub fn ProductionFeatureVector::distance(
  self : ProductionFeatureVector,
  other : ProductionFeatureVector,
) -> Double {
  let n = if self.values.length() < other.values.length() {
    self.values.length()
  } else {
    other.values.length()
  }
  let mut total = 0.0
  for i in 0..<n {
    let delta = self.values[i] - other.values[i]
    total += delta * delta
  }
  total.sqrt()
}

///|
pub fn ProductionFeatureVector::summary(
  self : ProductionFeatureVector,
) -> String {
  let entries : Array[String] = []
  for feature in self.features {
    entries.push(feature.name() + "=" + feature.value().to_string())
  }
  entries.join(",")
}

///|
/// Robust location and scale parameters learned from feature vectors.
pub struct ProductionFeatureScaler {
  centers : Array[Double]
  scales : Array[Double]
  mut fitted : Bool
}

///|
pub fn ProductionFeatureScaler::new(
  dimension? : Int = 1,
) -> ProductionFeatureScaler {
  let size = if dimension < 1 { 1 } else { dimension }
  {
    centers: Array::make(size, 0.0),
    scales: Array::make(size, 1.0),
    fitted: false,
  }
}

///|
pub fn ProductionFeatureScaler::dimension(
  self : ProductionFeatureScaler,
) -> Int {
  self.centers.length()
}

///|
pub fn ProductionFeatureScaler::fit(
  self : ProductionFeatureScaler,
  vectors : Array[ProductionFeatureVector],
) -> Bool {
  if vectors.length() == 0 {
    return false
  }
  let dimension = self.dimension()
  for i in 0..<dimension {
    let values : Array[Double] = []
    for vector in vectors {
      match vector.values.get(i) {
        None => ()
        Some(value) => if is_finite(value) { values.push(value) }
      }
    }
    if values.length() == 0 {
      self.centers[i] = 0.0
      self.scales[i] = 1.0
    } else {
      self.centers[i] = median(values)
      let deviation = median_absolute_deviation(values)
      self.scales[i] = if deviation < 1.0e-12 {
        let fallback = standard_deviation(values)
        if fallback < 1.0e-12 {
          1.0
        } else {
          fallback
        }
      } else {
        deviation
      }
    }
  }
  self.fitted = true
  true
}

///|
pub fn ProductionFeatureScaler::is_fitted(
  self : ProductionFeatureScaler,
) -> Bool {
  self.fitted
}

///|
pub fn ProductionFeatureScaler::centers(
  self : ProductionFeatureScaler,
) -> Array[Double] {
  let result : Array[Double] = []
  for center in self.centers {
    result.push(center)
  }
  result
}

///|
pub fn ProductionFeatureScaler::scales(
  self : ProductionFeatureScaler,
) -> Array[Double] {
  let result : Array[Double] = []
  for scale in self.scales {
    result.push(scale)
  }
  result
}

///|
pub fn ProductionFeatureScaler::transform(
  self : ProductionFeatureScaler,
  vector : ProductionFeatureVector,
) -> ProductionFeatureVector {
  let result : Array[ProductionFeature] = []
  for i, feature in vector.features {
    let value = if i < self.centers.length() {
      (feature.value() - self.centers[i]) / self.scales[i]
    } else {
      feature.value()
    }
    result.push(
      ProductionFeature::new(
        feature.kind(),
        value,
        feature.sample_count(),
        feature.source_window(),
      ),
    )
  }
  ProductionFeatureVector::new(result)
}

///|
pub fn ProductionFeatureScaler::inverse(
  self : ProductionFeatureScaler,
  values : Array[Double],
) -> Array[Double] {
  let result : Array[Double] = []
  let n = if values.length() < self.centers.length() {
    values.length()
  } else {
    self.centers.length()
  }
  for i in 0..<n {
    result.push(values[i] * self.scales[i] + self.centers[i])
  }
  result
}

///|
/// Configuration for an explainable feature extraction pass.
pub struct ProductionFeatureConfig {
  window_size : Int
  seasonal_period : Int
  include_distribution : Bool
  include_autocorrelation : Bool
  outlier_threshold : Double
}

///|
pub fn ProductionFeatureConfig::new(
  window_size? : Int = 32,
  seasonal_period? : Int = 0,
  include_distribution? : Bool = true,
  include_autocorrelation? : Bool = true,
  outlier_threshold? : Double = 3.0,
) -> ProductionFeatureConfig {
  {
    window_size: if window_size < 2 {
      2
    } else {
      window_size
    },
    seasonal_period: if seasonal_period < 0 {
      0
    } else {
      seasonal_period
    },
    include_distribution,
    include_autocorrelation,
    outlier_threshold: if outlier_threshold < 0.0 {
      0.0
    } else {
      outlier_threshold
    },
  }
}

///|
pub fn ProductionFeatureConfig::window_size(
  self : ProductionFeatureConfig,
) -> Int {
  self.window_size
}

///|
pub fn ProductionFeatureConfig::seasonal_period(
  self : ProductionFeatureConfig,
) -> Int {
  self.seasonal_period
}

///|
pub fn ProductionFeatureConfig::include_distribution(
  self : ProductionFeatureConfig,
) -> Bool {
  self.include_distribution
}

///|
pub fn ProductionFeatureConfig::include_autocorrelation(
  self : ProductionFeatureConfig,
) -> Bool {
  self.include_autocorrelation
}

///|
pub fn ProductionFeatureConfig::outlier_threshold(
  self : ProductionFeatureConfig,
) -> Double {
  self.outlier_threshold
}

///|
/// Feature pipeline used before a model or detector call.
pub struct ProductionFeaturePipeline {
  config : ProductionFeatureConfig
  windows : Array[ProductionTimeWindow]
  mut extracted : Int
  mut invalid : Int
}

///|
pub fn ProductionFeaturePipeline::new(
  config? : ProductionFeatureConfig = ProductionFeatureConfig::new(),
) -> ProductionFeaturePipeline {
  { config, windows: [], extracted: 0, invalid: 0 }
}

///|
pub fn ProductionFeaturePipeline::config(
  self : ProductionFeaturePipeline,
) -> ProductionFeatureConfig {
  self.config
}

///|
pub fn ProductionFeaturePipeline::extracted(
  self : ProductionFeaturePipeline,
) -> Int {
  self.extracted
}

///|
pub fn ProductionFeaturePipeline::invalid(
  self : ProductionFeaturePipeline,
) -> Int {
  self.invalid
}

///|
fn production_feature_skew(values : Array[Double]) -> Double {
  if values.length() < 2 {
    return 0.0
  }
  let center = mean(values)
  let deviation = standard_deviation(values)
  if deviation < 1.0e-12 {
    return 0.0
  }
  let mut total = 0.0
  for value in values {
    total += (value - center) /
      deviation *
      ((value - center) / deviation) *
      ((value - center) / deviation)
  }
  total / values.length().to_double()
}

///|
fn production_feature_kurtosis(values : Array[Double]) -> Double {
  if values.length() < 2 {
    return 0.0
  }
  let center = mean(values)
  let deviation = standard_deviation(values)
  if deviation < 1.0e-12 {
    return 0.0
  }
  let mut total = 0.0
  for value in values {
    let standardized = (value - center) / deviation
    total += standardized * standardized * standardized * standardized
  }
  total / values.length().to_double() - 3.0
}

///|
fn production_feature_outlier_ratio(
  values : Array[Double],
  threshold : Double,
) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let center = median(values)
  let scale = median_absolute_deviation(values)
  if scale < 1.0e-12 {
    return 0.0
  }
  let mut count = 0
  for value in values {
    if absolute(value - center) / scale > threshold {
      count += 1
    }
  }
  count.to_double() / values.length().to_double()
}

///|
fn production_feature_entropy(
  values : Array[Double],
  bins? : Int = 8,
) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let count = if bins < 2 { 2 } else { bins }
  let low = array_minimum(values)
  let high = array_maximum(values)
  if high <= low {
    return 0.0
  }
  let counts = Array::make(count, 0)
  for value in values {
    let index = if value >= high {
      count - 1
    } else {
      ((value - low) / (high - low) * count.to_double()).to_int()
    }
    counts[index] += 1
  }
  let mut entropy = 0.0
  for item in counts {
    if item > 0 {
      let probability = item.to_double() / values.length().to_double()
      entropy -= probability * @math.ln(probability)
    }
  }
  entropy
}

///|
pub fn ProductionFeaturePipeline::extract(
  self : ProductionFeaturePipeline,
  values : Array[Double],
) -> ProductionFeatureVector {
  let valid = remove_invalid(values)
  if valid.length() == 0 {
    self.invalid += 1
  }
  let width = self.config.window_size()
  let sample = if valid.length() <= width {
    valid
  } else {
    let result : Array[Double] = []
    for i in (valid.length() - width)..<valid.length() {
      result.push(valid[i])
    }
    result
  }
  let n = sample.length()
  let center = median(sample)
  let spread = interquartile_range(sample)
  let trend = linear_slope(sample)
  let volatility = standard_deviation(sample)
  let difference = mean_absolute_difference(sample)
  let autocorrelation = if self.config.include_autocorrelation() {
    autocorrelation(sample, 1)
  } else {
    0.0
  }
  let entropy = if self.config.include_distribution() {
    production_feature_entropy(sample)
  } else {
    0.0
  }
  let seasonal = if self.config.seasonal_period() > 1 {
    seasonal_strength(sample, self.config.seasonal_period())
  } else {
    0.0
  }
  let missing_ratio = if values.length() == 0 {
    0.0
  } else {
    1.0 - valid.length().to_double() / values.length().to_double()
  }
  let features : Array[ProductionFeature] = [
    ProductionFeature::new(LevelFeature, center, n, width),
    ProductionFeature::new(SpreadFeature, spread, n, width),
    ProductionFeature::new(TrendFeature, trend, n, width),
    ProductionFeature::new(VolatilityFeature, volatility, n, width),
    ProductionFeature::new(
      SkewFeature,
      production_feature_skew(sample),
      n,
      width,
    ),
    ProductionFeature::new(
      KurtosisFeature,
      production_feature_kurtosis(sample),
      n,
      width,
    ),
    ProductionFeature::new(AutocorrelationFeature, autocorrelation, n, width),
    ProductionFeature::new(DifferenceFeature, difference, n, width),
    ProductionFeature::new(QuantileFeature, quantile(sample, 0.9), n, width),
    ProductionFeature::new(DistributionEntropyFeature, entropy, n, width),
    ProductionFeature::new(
      MissingRatioFeature,
      missing_ratio,
      values.length(),
      width,
    ),
    ProductionFeature::new(
      OutlierRatioFeature,
      production_feature_outlier_ratio(sample, self.config.outlier_threshold()),
      n,
      width,
    ),
    ProductionFeature::new(SeasonalStrengthFeature, seasonal, n, width),
  ]
  self.extracted += 1
  ProductionFeatureVector::new(features)
}

///|
pub fn ProductionFeaturePipeline::extract_from_window(
  self : ProductionFeaturePipeline,
  window : ProductionTimeWindow,
) -> ProductionFeatureVector {
  self.extract(window.values())
}

///|
pub fn ProductionFeaturePipeline::extract_batch(
  self : ProductionFeaturePipeline,
  batches : Array[Array[Double]],
) -> Array[ProductionFeatureVector] {
  let result : Array[ProductionFeatureVector] = []
  for batch in batches {
    result.push(self.extract(batch))
  }
  result
}

///|
pub fn ProductionFeaturePipeline::feature_names(
  self : ProductionFeaturePipeline,
) -> Array[String] {
  ignore(self.config.window_size())
  let names : Array[String] = []
  for
    kind in [
      LevelFeature,
      SpreadFeature,
      TrendFeature,
      VolatilityFeature,
      SkewFeature,
      KurtosisFeature,
      AutocorrelationFeature,
      DifferenceFeature,
      QuantileFeature,
      DistributionEntropyFeature,
      MissingRatioFeature,
      OutlierRatioFeature,
      SeasonalStrengthFeature,
    ] {
    names.push(production_feature_kind_name(kind))
  }
  names
}

///|
/// Builds a compact feature-to-score summary used for explanations.
pub fn production_feature_contributions(
  vector : ProductionFeatureVector,
  weights : Array[Double],
) -> Array[EvidenceContribution] {
  let result : Array[EvidenceContribution] = []
  let features = vector.features()
  let n = if features.length() < weights.length() {
    features.length()
  } else {
    weights.length()
  }
  for i in 0..<n {
    result.push(
      EvidenceContribution::new(
        features[i].name(),
        features[i].value(),
        weight=weights[i],
      ),
    )
  }
  result
}

///|
/// Computes a robustly scaled distance between two production windows.
pub fn production_window_feature_distance(
  left : Array[Double],
  right : Array[Double],
  config? : ProductionFeatureConfig = ProductionFeatureConfig::new(),
) -> Double {
  let pipeline = ProductionFeaturePipeline::new(config~)
  pipeline.extract(left).distance(pipeline.extract(right))
}
