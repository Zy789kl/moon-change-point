///|
fn sample_replay_records() -> Array[ReplayRecord] {
  [
    ReplayRecord::new(
      SignalPoint::new(1L, 1.0),
      DetectionResult::quiet(index=0),
      3L,
    ),
    ReplayRecord::new(
      SignalPoint::new(2L, 4.0),
      DetectionResult::new(true, 0.8, 0.9, Increase, 1),
      5L,
    ),
    ReplayRecord::new(
      SignalPoint::new(3L, 2.0),
      DetectionResult::new(false, 0.2, 0.4, Decrease, 2),
      7L,
    ),
  ]
}

///|
test "replay summary counts changed records" {
  let summary = summarize_replay(sample_replay_records())
  assert_eq(summary.total, 3)
  assert_eq(summary.changed, 1)
  assert_eq(summary.first_change, 1)
  assert_eq(summary.last_change, 1)
  assert_true(summary.mean_score > 0.0)
  assert_eq(summary.elapsed, 15L)
}

///|
test "replay checksum and values are stable" {
  let records = sample_replay_records()
  assert_eq(replay_values(records), [1.0, 4.0, 2.0])
  assert_eq(replay_changed_indices(records), [1])
  assert_true(replay_checksum(records) > 0.0)
}

///|
test "replay window clamps invalid ranges" {
  let records = sample_replay_records()
  assert_eq(replay_window(records, -3, 2).length(), 2)
  assert_eq(replay_window(records, 2, 99).length(), 1)
  assert_eq(replay_window(records, 2, 2).length(), 0)
}

///|
test "latency percentile handles ordered elapsed values" {
  let records = sample_replay_records()
  assert_eq(replay_latency_percentile(records, 0.0), 3L)
  assert_eq(replay_latency_percentile(records, 1.0), 7L)
  assert_true(
    replay_summary_markdown(summarize_replay(records)).contains("changed"),
  )
}

///|
test "replay comparator accepts equivalent results" {
  let comparator = ReplayComparator::new(
    score_tolerance=0.01,
    confidence_tolerance=0.01,
  )
  let expected = DetectionResult::new(true, 0.5, 0.6, Increase, 4)
  let actual = DetectionResult::new(true, 0.505, 0.595, Increase, 4)
  assert_true(comparator.compare(expected, actual))
  assert_eq(comparator.compared(), 1)
  assert_eq(comparator.mismatches(), 0)
}

///|
test "replay comparator records mismatches" {
  let comparator = ReplayComparator::new()
  let expected = DetectionResult::quiet(index=1)
  let actual = DetectionResult::new(true, 1.0, 1.0, Increase, 1)
  assert_true(!comparator.compare(expected, actual))
  assert_eq(comparator.mismatches(), 1)
}

///|
test "evidence contribution preserves weighted value" {
  let item = EvidenceContribution::new("test", 2.0, weight=0.5)
  assert_eq(item.contribution, 1.0)
}

///|
test "explanation contains operational context" {
  let result = DetectionResult::new(true, 0.8, 0.9, Increase, 3)
  let explanation = make_explanation(result, 10.0, 14.0, "cusum")
  assert_eq(explanation.baseline, 10.0)
  assert_eq(explanation.observed, 14.0)
  assert_true(explanation.relative_change > 0.0)
  assert_true(explanation.recommendation.contains("cusum"))
  assert_true(explanation_strength(explanation) > 0.0)
}

///|
test "quiet explanation recommends monitoring" {
  let explanation = make_explanation(
    DetectionResult::quiet(index=0),
    2.0,
    2.0,
    "baseline",
  )
  assert_true(explanation.recommendation.contains("monitoring"))
  match strongest_contribution(explanation) {
    None => fail("contribution missing")
    Some(item) => assert_true(item.contribution >= 0.0)
  }
}

///|
test "explanation CSV and markdown are exportable" {
  let explanation = make_explanation(
    DetectionResult::new(true, 0.9, 0.9, Increase, 3),
    1.0,
    2.0,
    "detector",
  )
  assert_true(explanation_csv_header().contains("relative_change"))
  assert_true(explanation_csv(explanation).contains("3,true"))
  assert_true(explanation_markdown(explanation).contains("recommendation"))
}

///|
test "batch explanations truncate to common length" {
  let results = [
    DetectionResult::quiet(index=0),
    DetectionResult::quiet(index=1),
  ]
  let explanations = explain_batch(results, 0.0, [1.0], "batch")
  assert_eq(explanations.length(), 1)
  assert_eq(explanation_alerts(explanations), 0)
}
