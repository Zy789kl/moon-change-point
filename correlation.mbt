///|
/// Cross-series relationship helpers for multivariate monitoring.
pub fn safe_correlation(left : Array[Double], right : Array[Double]) -> Double {
  clamp_probability((correlation(left, right) + 1.0) / 2.0) * 2.0 - 1.0
}

///|
pub fn covariance_matrix(series : Array[Array[Double]]) -> SquareMatrix {
  let dimension = series.length()
  let result = SquareMatrix::new(dimension)
  for row in 0..<dimension {
    for column in 0..<dimension {
      result.set(
        row,
        column,
        if row < series.length() && column < series.length() {
          covariance(series[row], series[column])
        } else {
          0.0
        },
      )
    }
  }
  result
}

///|
pub fn correlation_matrix(series : Array[Array[Double]]) -> SquareMatrix {
  let dimension = series.length()
  let result = SquareMatrix::identity(dimension)
  for row in 0..<dimension {
    for column in 0..<dimension {
      result.set(
        row,
        column,
        if row == column {
          1.0
        } else {
          safe_correlation(series[row], series[column])
        },
      )
    }
  }
  result
}

///|
pub fn average_pairwise_correlation(series : Array[Array[Double]]) -> Double {
  if series.length() < 2 {
    return 0.0
  }
  let mut total = 0.0
  let mut pairs = 0
  for row in 0..<series.length() {
    for column in (row + 1)..<series.length() {
      total += absolute(safe_correlation(series[row], series[column]))
      pairs += 1
    }
  }
  if pairs == 0 {
    0.0
  } else {
    total / pairs.to_double()
  }
}

///|
pub fn lagged_correlation(
  left : Array[Double],
  right : Array[Double],
  lag : Int,
) -> Double {
  if lag < 0 {
    return lagged_correlation(right, left, -lag)
  }
  if lag >= left.length() || lag >= right.length() {
    return 0.0
  }
  let a : Array[Double] = []
  let b : Array[Double] = []
  let length = if left.length() - lag < right.length() {
    left.length() - lag
  } else {
    right.length()
  }
  for i in 0..<length {
    a.push(left[i + lag])
    b.push(right[i])
  }
  safe_correlation(a, b)
}

///|
pub fn best_lag(
  left : Array[Double],
  right : Array[Double],
  maximum_lag : Int,
) -> Int {
  let bound = if maximum_lag < 0 { 0 } else { maximum_lag }
  let mut best = 0
  let mut best_score = absolute(lagged_correlation(left, right, 0))
  for lag in 1..<(bound + 1) {
    let score = absolute(lagged_correlation(left, right, lag))
    if score > best_score {
      best = lag
      best_score = score
    }
  }
  best
}

///|
pub fn rolling_correlation(
  left : Array[Double],
  right : Array[Double],
  window_size : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  let safe = if window_size < 2 { 2 } else { window_size }
  let length = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<length {
    let start = if i + 1 < safe { 0 } else { i + 1 - safe }
    let a : Array[Double] = []
    let b : Array[Double] = []
    for j in start..<(i + 1) {
      a.push(left[j])
      b.push(right[j])
    }
    result.push(safe_correlation(a, b))
  }
  result
}

///|
pub fn correlated_change_score(
  before : Array[Array[Double]],
  after : Array[Array[Double]],
) -> Double {
  let before_matrix = correlation_matrix(before)
  let after_matrix = correlation_matrix(after)
  let dimension = if before.length() < after.length() {
    before.length()
  } else {
    after.length()
  }
  let mut total = 0.0
  for row in 0..<dimension {
    for column in 0..<dimension {
      total += absolute(
        before_matrix.get(row, column) - after_matrix.get(row, column),
      )
    }
  }
  if dimension == 0 {
    0.0
  } else {
    total / (dimension * dimension).to_double()
  }
}

///|
pub fn correlation_alert(
  before : Array[Array[Double]],
  after : Array[Array[Double]],
  threshold? : Double = 0.25,
) -> DetectionResult {
  let score = correlated_change_score(before, after)
  DetectionResult::new(
    score >= threshold,
    score,
    clamp_probability(score),
    DistributionShift,
    0,
    evidence=score,
  )
}
