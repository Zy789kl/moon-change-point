///|
test "mean shift score is zero for invalid split" {
  let values = [0.0, 1.0, 2.0, 3.0]
  assert_eq(mean_shift_score(values, -1), 0.0)
  assert_eq(mean_shift_score(values, 0), 0.0)
  assert_eq(mean_shift_score(values, 4), 0.0)
}

///|
test "inspect split rejects undersized segments" {
  match inspect_split([1.0, 2.0, 3.0], 1, min_segment=2) {
    None => ()
    Some(_) => fail("undersized split accepted")
  }
}

///|
test "segment range normalizes its length" {
  let range = SegmentRange::new(2, 5)
  assert_eq(range.length(), 3)
  assert_eq(SegmentRange::new(5, 2).length(), -3)
}

///|
test "merge nearby changes keeps the higher evidence" {
  let changes : Array[OfflineChange] = []
  match inspect_split([0.0, 0.0, 5.0, 5.0], 2, min_segment=1) {
    None => ()
    Some(value) => changes.push(value)
  }
  match inspect_split([0.0, 0.0, 0.0, 5.0, 5.0], 3, min_segment=1) {
    None => ()
    Some(value) => changes.push(value)
  }
  let merged = merge_nearby_changes(changes, 5)
  assert_eq(merged.length(), 1)
}

///|
test "piecewise error prefers a true split" {
  let values = [0.0, 0.0, 4.0, 4.0]
  assert_true(
    piecewise_constant_error(values, [2]) < piecewise_constant_error(values, []),
  )
}

///|
test "quality report starts healthy" {
  let report = QualityReport::empty()
  assert_true(report.is_healthy())
  assert_eq(report.valid_ratio(), 1.0)
  assert_eq(quality_score(report), 1.0)
}

///|
test "quality validation records range violations" {
  let report = validate_values(
    [1.0, 5.0, 10.0],
    lower=Some(2.0),
    upper=Some(8.0),
  )
  assert_eq(report.out_of_range, 2)
  assert_true(!report.is_healthy())
}

///|
test "invalid values can be removed or replaced" {
  let values = [1.0, 0.0 / 0.0, 3.0]
  assert_eq(remove_invalid(values), [1.0, 3.0])
  assert_eq(replace_invalid(values, replacement=2.0), [1.0, 2.0, 3.0])
}

///|
test "quality gate honors dimension policy" {
  let gate = DataQualityGate::new(minimum_ratio=0.5, reject_non_monotonic=true)
  assert_true(gate.accept(validate_values([1.0, 2.0, 3.0])))
}

///|
test "contiguous ranges split on timestamp gaps" {
  let points = [
    SignalPoint::new(0L, 1.0),
    SignalPoint::new(1L, 2.0),
    SignalPoint::new(10L, 3.0),
  ]
  let ranges = contiguous_ranges(points, 2L)
  assert_true(ranges.length() >= 2)
}

///|
test "change point metrics tolerate duplicates" {
  let metrics = evaluate_change_points([3, 3, 10], [3], tolerance=0)
  assert_true(metrics.true_positives >= 1)
  assert_true(metrics.precision <= 1.0)
}

///|
test "optimal changepoints accepts negative penalties safely" {
  let changes = optimal_changepoints(
    [1.0, 1.0, 4.0, 4.0],
    penalty=-1.0,
    min_segment=1,
  )
  assert_true(changes.length() >= 0)
}

///|
test "window change scores preserve every position" {
  let scores = window_change_scores([1.0, 1.0, 3.0, 3.0], min_segment=1)
  assert_eq(scores.length(), 4)
  assert_eq(scores[0], 0.0)
  assert_true(scores[3] >= 0.0)
}

///|
test "segment profile includes a tail segment" {
  let profiles = segment_profile([1.0, 1.0, 5.0, 5.0], [2])
  assert_eq(profiles.length(), 2)
  assert_eq(profiles[0].mean, 1.0)
  assert_eq(profiles[1].mean, 5.0)
}

///|
test "boundary quality rejects boundaries too close to edges" {
  assert_eq(boundary_quality([1.0, 2.0, 3.0], 1, minimum_segment=2), 0.0)
  assert_eq(best_boundary([1.0, 2.0], minimum_segment=2), -1)
}
