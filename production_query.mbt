///|
/// Aggregation function for a production query window.
pub(all) enum ProductionWindowFunction {
  QueryMean
  QuerySum
  QueryMinimum
  QueryMaximum
  QueryMedian
  QueryP95
  QueryCount
  QueryRate
  QueryChange
}

///|
pub fn production_window_function_name(
  kind : ProductionWindowFunction,
) -> String {
  match kind {
    QueryMean => "mean"
    QuerySum => "sum"
    QueryMinimum => "minimum"
    QueryMaximum => "maximum"
    QueryMedian => "median"
    QueryP95 => "p95"
    QueryCount => "count"
    QueryRate => "rate"
    QueryChange => "change"
  }
}

///|
pub struct ProductionQueryWindow {
  start : Int64
  end : Int64
}

///|
pub fn ProductionQueryWindow::new(
  start : Int64,
  end : Int64,
) -> ProductionQueryWindow {
  { start, end: if end < start { start } else { end } }
}

///|
pub fn ProductionQueryWindow::start(self : ProductionQueryWindow) -> Int64 {
  self.start
}

///|
pub fn ProductionQueryWindow::end(self : ProductionQueryWindow) -> Int64 {
  self.end
}

///|
pub fn ProductionQueryWindow::contains(
  self : ProductionQueryWindow,
  timestamp : Int64,
) -> Bool {
  timestamp >= self.start && timestamp < self.end
}

///|
pub fn ProductionQueryWindow::duration(self : ProductionQueryWindow) -> Int64 {
  self.end - self.start
}

///|
pub struct ProductionQueryResult {
  metric : String
  window : ProductionQueryWindow
  function : ProductionWindowFunction
  value : Double
  count : Int
  quality : Double
}

///|
pub fn ProductionQueryResult::metric(self : ProductionQueryResult) -> String {
  self.metric
}

///|
pub fn ProductionQueryResult::window(
  self : ProductionQueryResult,
) -> ProductionQueryWindow {
  self.window
}

///|
pub fn ProductionQueryResult::function(
  self : ProductionQueryResult,
) -> ProductionWindowFunction {
  self.function
}

///|
pub fn ProductionQueryResult::value(self : ProductionQueryResult) -> Double {
  self.value
}

///|
pub fn ProductionQueryResult::count(self : ProductionQueryResult) -> Int {
  self.count
}

///|
pub fn ProductionQueryResult::quality(self : ProductionQueryResult) -> Double {
  self.quality
}

///|
pub fn ProductionQueryResult::summary(self : ProductionQueryResult) -> String {
  self.metric +
  ":" +
  production_window_function_name(self.function) +
  "=" +
  self.value.to_string() +
  " count=" +
  self.count.to_string() +
  " quality=" +
  self.quality.to_string()
}

///|
pub struct ProductionSeriesQuery {
  metric : String
  window : ProductionQueryWindow
  function : ProductionWindowFunction
  minimum_quality : Double
}

///|
pub fn ProductionSeriesQuery::new(
  metric : String,
  window : ProductionQueryWindow,
  function? : ProductionWindowFunction = QueryMean,
  minimum_quality? : Double = 0.0,
) -> ProductionSeriesQuery {
  {
    metric,
    window,
    function,
    minimum_quality: clamp_probability(minimum_quality),
  }
}

///|
pub fn ProductionSeriesQuery::metric(self : ProductionSeriesQuery) -> String {
  self.metric
}

///|
pub fn ProductionSeriesQuery::window(
  self : ProductionSeriesQuery,
) -> ProductionQueryWindow {
  self.window
}

///|
pub fn ProductionSeriesQuery::function(
  self : ProductionSeriesQuery,
) -> ProductionWindowFunction {
  self.function
}

///|
pub fn ProductionSeriesQuery::minimum_quality(
  self : ProductionSeriesQuery,
) -> Double {
  self.minimum_quality
}

///|
fn production_query_values(
  series : ProductionMetricSeries,
  window : ProductionQueryWindow,
) -> (Array[Double], Int) {
  let values : Array[Double] = []
  let mut late = 0
  for sample in series.window().to_array() {
    if window.contains(sample.timestamp()) {
      if is_finite(sample.value()) {
        values.push(sample.value())
      }
      if sample.late() {
        late += 1
      }
    }
  }
  (values, late)
}

///|
fn production_query_value(
  function : ProductionWindowFunction,
  values : Array[Double],
  window : ProductionQueryWindow,
) -> Double {
  match function {
    QueryMean => mean(values)
    QuerySum => sum(values)
    QueryMinimum => array_minimum(values)
    QueryMaximum => array_maximum(values)
    QueryMedian => median(values)
    QueryP95 => quantile(values, 0.95)
    QueryCount => values.length().to_double()
    QueryRate =>
      if window.duration() <= 0L {
        0.0
      } else {
        values.length().to_double() / window.duration().to_double()
      }
    QueryChange =>
      if values.length() < 2 {
        0.0
      } else {
        values[values.length() - 1] - values[0]
      }
  }
}

///|
pub fn ProductionSeriesQuery::execute(
  self : ProductionSeriesQuery,
  series : ProductionMetricSeries,
) -> ProductionQueryResult {
  let selected = production_query_values(series, self.window)
  let quality = if selected.0.length() + selected.1 == 0 {
    1.0
  } else {
    selected.0.length().to_double() /
    (selected.0.length() + selected.1).to_double()
  }
  {
    metric: self.metric,
    window: self.window,
    function: self.function,
    value: if quality >= self.minimum_quality {
      production_query_value(self.function, selected.0, self.window)
    } else {
      0.0
    },
    count: selected.0.length(),
    quality,
  }
}

///|
pub fn production_query_rollup(
  series : ProductionMetricSeries,
  start : Int64,
  end : Int64,
  step : Int64,
  function? : ProductionWindowFunction = QueryMean,
) -> Array[ProductionQueryResult] {
  let result : Array[ProductionQueryResult] = []
  let safe_step = if step < 1L { 1L } else { step }
  let mut cursor = start
  while cursor < end {
    let window = ProductionQueryWindow::new(
      cursor,
      if cursor + safe_step > end {
        end
      } else {
        cursor + safe_step
      },
    )
    result.push(
      ProductionSeriesQuery::new(series.name(), window, function~).execute(
        series,
      ),
    )
    cursor += safe_step
  }
  result
}

///|
pub fn production_query_results_markdown(
  results : Array[ProductionQueryResult],
) -> String {
  let mut output = "| metric | start | end | function | value | count | quality |\n|---|---:|---:|---|---:|---:|---:|\n"
  for result in results {
    output = output +
      "| " +
      result.metric() +
      " | " +
      result.window().start().to_string() +
      " | " +
      result.window().end().to_string() +
      " | " +
      production_window_function_name(result.function()) +
      " | " +
      result.value().to_string() +
      " | " +
      result.count().to_string() +
      " | " +
      result.quality().to_string() +
      " |\n"
  }
  output
}

///|
/// Returns the largest absolute changes in a numeric series.
pub fn production_top_changes(
  values : Array[Double],
  maximum? : Int = 8,
) -> Array[Int] {
  let candidates : Array[(Int, Double)] = []
  if values.length() < 2 {
    return []
  }
  for i in 1..<values.length() {
    candidates.push((i, absolute(values[i] - values[i - 1])))
  }
  for i in 0..<candidates.length() {
    for j in (i + 1)..<candidates.length() {
      if candidates[j].1 > candidates[i].1 {
        let value = candidates[i]
        candidates[i] = candidates[j]
        candidates[j] = value
      }
    }
  }
  let result : Array[Int] = []
  let limit = if maximum < 0 {
    0
  } else if maximum > candidates.length() {
    candidates.length()
  } else {
    maximum
  }
  for i in 0..<limit {
    result.push(candidates[i].0)
  }
  result
}
