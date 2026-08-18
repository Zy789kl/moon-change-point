///|
test "fixed window aggregation records timestamps" {
  let aggregator = WindowAggregator::new(2)
  ignore(aggregator.push(SignalPoint::new(10L, 1.0)))
  match aggregator.push(SignalPoint::new(20L, 3.0)) {
    None => fail("aggregate missing")
    Some(value) => {
      assert_eq(value.start_timestamp, 10L)
      assert_eq(value.end_timestamp, 20L)
      assert_eq(value.count, 2)
    }
  }
}

///|
test "fixed window standard deviation is finite" {
  let aggregator = WindowAggregator::new(2, kind=StandardDeviationAggregate)
  ignore(aggregator.push(SignalPoint::new(1L, 2.0)))
  match aggregator.push(SignalPoint::new(2L, 4.0)) {
    None => fail("aggregate missing")
    Some(value) => assert_true(is_finite(value.value))
  }
}

///|
test "adaptive baseline ignores non finite data" {
  let baseline = AdaptiveBaseline::new(learning_rate=0.1)
  ignore(baseline.update(0.0 / 0.0))
  assert_eq(baseline.sample_count(), 0)
  ignore(baseline.update(4.0))
  assert_eq(baseline.sample_count(), 1)
}

///|
test "trend shift reset is idempotent" {
  let detector = TrendShiftDetector::new(window_size=3)
  detector.reset()
  detector.reset()
  assert_true(detector.update(1.0).score >= 0.0)
}

///|
test "robust z reset is idempotent" {
  let detector = RobustZDetector::new(window_size=3)
  detector.reset()
  detector.reset()
  assert_true(detector.update(1.0).score >= 0.0)
}

///|
test "score calibrator retains positive and negative weights" {
  let calibrator = ScoreCalibrator::new(max_observations=10)
  calibrator.push(0.1, false, weight=2.0)
  calibrator.push(0.9, true, weight=3.0)
  assert_eq(calibrator.count(), 2)
  assert_eq(calibrator.positive_weight(), 3.0)
  assert_eq(calibrator.negative_weight(), 2.0)
}

///|
test "score calibrator best report is bounded" {
  let calibrator = ScoreCalibrator::new()
  for score in [0.1, 0.2, 0.8, 0.9] {
    calibrator.push(score, score > 0.5)
  }
  let report = calibrator.best([0.2, 0.5, 0.8])
  assert_true(report.precision >= 0.0 && report.precision <= 1.0)
  assert_true(report.recall >= 0.0 && report.recall <= 1.0)
}

///|
test "event deduplication honors timestamp gap" {
  let first = incident_event("x", 1L, 0.8)
  let second = incident_event("x", 2L, 0.8)
  let third = incident_event("x", 10L, 0.8)
  let unique = deduplicate_events([first, second, third], 3L)
  assert_true(unique.length() <= 3)
  assert_true(unique.length() >= 2)
}

///|
test "event history latest is optional" {
  let history = EventHistory::new()
  match history.latest() {
    None => ()
    Some(_) => fail("empty history has latest")
  }
  history.push(incident_event("x", 1L, 0.8))
  match history.latest() {
    None => fail("latest missing")
    Some(event) => assert_eq(event.metric, "x")
  }
}

///|
test "multivariate vector validation detects non finite values" {
  let point = VectorPoint::new(1L, [1.0, 0.0 / 0.0])
  assert_true(!point.is_valid())
  assert_eq(point.dimension(), 2)
}

///|
test "online vector stats rejects wrong dimensions" {
  let stats = OnlineVectorStats::new(2)
  assert_true(!stats.push([1.0]))
  assert_eq(stats.count(), 0)
  assert_true(stats.push([1.0, 2.0]))
  assert_eq(stats.count(), 1)
}

///|
test "vector standardization preserves dimension" {
  let stats = OnlineVectorStats::new(2)
  for value in [[1.0, 2.0], [2.0, 4.0], [3.0, 6.0]] {
    ignore(stats.push(value))
  }
  assert_eq(stats.means().length(), 2)
  assert_eq(stats.variances().length(), 2)
  assert_eq(stats.standardized([2.0, 4.0]).length(), 2)
}

///|
test "sampling split fractions are clamped" {
  let split = split_train_test([1.0, 2.0, 3.0], train_fraction=2.0)
  assert_eq(split.0.length(), 3)
  assert_eq(split.1.length(), 0)
  let empty = split_train_test([1.0, 2.0, 3.0], train_fraction=-1.0)
  assert_eq(empty.0.length(), 0)
}

///|
test "histogram bounds are normalized" {
  let histogram = Histogram::new(5.0, 1.0, 0)
  histogram.push(1.0)
  histogram.push(5.0)
  assert_eq(histogram.bins(), 1)
  assert_eq(histogram.total(), 2)
}

///|
test "matrix Mahalanobis diagonal is safe with zero variance" {
  assert_eq(diagonal_mahalanobis([1.0], [1.0], [0.0]), 0.0)
  assert_true(diagonal_mahalanobis([2.0], [1.0], [1.0]) > 0.0)
}

///|
test "backfill interpolation preserves endpoints" {
  let points = [SignalPoint::new(0L, 0.0), SignalPoint::new(2L, 2.0)]
  let result = interpolate_points(points, 1L)
  assert_eq(result[0].value, 0.0)
  assert_eq(result[result.length() - 1].value, 2.0)
}

///|
test "seasonal naive forecast handles one period" {
  let result = seasonal_naive_forecast([1.0, 2.0], 1, 3)
  assert_eq(result, [2.0, 2.0, 2.0])
}

///|
test "feature change score is zero for matching values" {
  assert_eq(feature_change_score([1.0, 2.0], [1.0, 2.0]), 0.0)
}

///|
test "reporting rows are separated by newlines" {
  let result = DetectionResult::quiet(index=0)
  let csv = results_csv([result])
  assert_true(csv.contains("\n"))
  assert_true(csv.length() > detection_csv_header().length())
}

///|
test "quality score rewards complete stable values" {
  let report = validate_values([1.0, 1.0, 1.0])
  assert_true(quality_score(report) > 0.9)
}

///|
test "quality score penalizes invalid values" {
  let report = validate_values([1.0, 0.0 / 0.0, 1.0])
  assert_true(quality_score(report) < 1.0)
}

///|
test "change point summary uses timestamp" {
  let point = ChangePoint::from_result(
    SignalPoint::new(42L, 2.0),
    DetectionResult::quiet(index=1),
    "test",
    2.0,
  )
  assert_true(point.summary().contains("42"))
}

///|
test "routing priority labels are positive" {
  let decision = route_alert(routed_event(0.9, false))
  assert_true(decision.priority > 0)
}

///|
test "benchmark markdown contains every detector row" {
  let markdown = benchmark_markdown(benchmark_suite(rounds=1))
  assert_true(markdown.contains("cusum"))
  assert_true(markdown.contains("robust-z"))
  assert_true(markdown.contains("projection-ensemble"))
}
