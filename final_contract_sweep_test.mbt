///|
test "empty arrays are safe across core APIs" {
  assert_eq(first_difference([]), [])
  assert_eq(second_difference([]), [])
  assert_eq(cumulative_total([]), [])
  assert_eq(rolling_mean([], 3), [])
  assert_eq(rolling_slope([], 3), [])
}

///|
test "probability clamping is idempotent" {
  assert_eq(clamp_probability(clamp_probability(-1.0)), 0.0)
  assert_eq(clamp_probability(clamp_probability(2.0)), 1.0)
  assert_eq(clamp_probability(clamp_probability(0.4)), 0.4)
}

///|
test "result quiet helper accepts negative indices" {
  let result = DetectionResult::quiet(index=-10)
  assert_true(!result.changed)
  assert_eq(result.index, -10)
}

///|
test "stats summary empty fields are all zero" {
  let summary = StatsSummary::empty()
  assert_eq(summary.count, 0)
  assert_eq(summary.mean, 0.0)
  assert_eq(summary.minimum, 0.0)
  assert_eq(summary.maximum, 0.0)
}

///|
test "window capacity is normalized" {
  let window = DoubleWindow::new(0)
  assert_eq(window.capacity(), 1)
  assert_true(window.is_empty())
}

///|
test "reorder buffer capacity is normalized" {
  let buffer = ReorderBuffer::new(capacity=0)
  assert_eq(buffer.pending_count(), 0)
  assert_eq(buffer.dropped_count(), 0)
}

///|
test "offline empty input has empty profile" {
  assert_eq(segment_profile([], []).length(), 1)
  assert_eq(segment_means([], []), [0.0])
  assert_eq(segment_variances([], []), [0.0])
}

///|
test "diagnostics batch accepts no splits" {
  assert_eq(diagnostics_batch([1.0, 2.0], []).length(), 0)
  assert_eq(actionable_diagnostics([]), 0)
}

///|
test "correlation lag bounds are safe" {
  assert_eq(best_lag([], [], 4), 0)
  assert_eq(lagged_correlation([], [], 0), 0.0)
  assert_eq(rolling_correlation([], [], 3), [])
}

///|
test "forecast losses are finite for aligned values" {
  let actual = [1.0, 2.0, 3.0]
  let predicted = [1.0, 2.5, 2.0]
  assert_true(is_finite(forecast_mae(actual, predicted)))
  assert_true(is_finite(forecast_rmse(actual, predicted)))
  assert_true(is_finite(forecast_mape(actual, predicted)))
}

///|
test "calibration report handles no observations" {
  let report = evaluate_threshold([], 0.5)
  assert_eq(report.true_positives, 0)
  assert_eq(report.false_positives, 0)
  assert_eq(report.f1, 0.0)
}

///|
test "reservoir sample filters invalid values" {
  let reservoir = ReservoirSample::new(3)
  reservoir.push(0.0 / 0.0)
  reservoir.push(1.0)
  assert_eq(reservoir.seen(), 1)
  assert_eq(reservoir.values(), [1.0])
}

///|
test "bootstrap empty sample has zero replicates" {
  let estimate = bootstrap_mean([], replicates=10)
  assert_eq(estimate.replicates, 0)
  assert_eq(estimate.standard_error, 0.0)
}

///|
test "SLO targets are clamped" {
  let tracker = SloTracker::new(target=2.0, burn_limit=-1.0)
  let report = tracker.close_period()
  assert_true(report.availability() >= 0.0)
  assert_true(report.budget() >= 0.0)
}

///|
test "incident clustering is stable for empty input" {
  let incidents = cluster_incidents([], 3L)
  assert_eq(incidents.length(), 0)
  assert_eq(incident_alert_count(incidents), 0)
}

///|
test "routing empty input produces a header" {
  assert_eq(route_alerts([]).length(), 0)
  assert_true(routing_summary([]).contains("channel"))
}

///|
test "routing budget remaining never goes negative" {
  let budget = RoutingBudget::new(capacity=1)
  let decision = route_alert(routed_event(0.7, false))
  ignore(budget.allow(decision))
  ignore(budget.allow(decision))
  assert_true(budget.remaining() >= 0)
}

///|
test "matrix zero size remains well formed" {
  let matrix = SquareMatrix::new(0)
  assert_eq(matrix.size(), 1)
  assert_eq(matrix.diagonal(), [0.0])
}

///|
test "vector helpers handle empty dimensions" {
  assert_eq(vector_norm([]), 0.0)
  assert_eq(vector_dot([], []), 0.0)
  assert_eq(euclidean_distance([], []), 0.0)
  assert_eq(cosine_similarity([], []), 0.0)
}

///|
test "signal checksum ignores non finite observations" {
  assert_eq(signal_checksum([0.0 / 0.0, 2.0]), 4.0)
}

///|
test "catalog recommendations are exhaustive for booleans" {
  for multivariate in [false, true] {
    for offline in [false, true] {
      for robust in [false, true] {
        assert_true(
          recommended_detector(multivariate, offline, robust).length() > 0,
        )
      }
    }
  }
}

///|
test "explanation relative change is safe at zero baseline" {
  assert_eq(relative_change(0.0, 5.0), 5.0)
  assert_eq(absolute_change(2.0, 5.0), 3.0)
  assert_eq(direction_name(change_direction_from_values(2.0, 5.0)), "increase")
}
