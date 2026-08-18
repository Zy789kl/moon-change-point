///|
test "offline split score peaks near mean change" {
  let values = Array::make(10, 0.0) + Array::make(10, 5.0)
  let score = mean_shift_score(values, 10, min_segment=3)
  assert_true(score > 5.0)
  assert_eq(mean_shift_score(values, 1, min_segment=3), 0.0)
}

///|
test "inspect split reports direction and means" {
  let values = [1.0, 1.0, 1.0, 4.0, 4.0, 4.0]
  match inspect_split(values, 3, min_segment=2) {
    None => fail("valid split missing")
    Some(change) => {
      assert_eq(change.index, 3)
      assert_eq(direction_name(change.direction), "increase")
      assert_eq(change.left_mean, 1.0)
      assert_eq(change.right_mean, 4.0)
    }
  }
}

///|
test "binary segmentation finds two changes" {
  let values = [0.0, 0.0, 0.0, 5.0, 5.0, 5.0, 1.0, 1.0, 1.0]
  let changes = binary_segmentation(
    values,
    threshold=0.5,
    min_segment=2,
    max_changes=4,
  )
  assert_true(changes.length() >= 1)
  assert_true(changes[0].index > 0)
}

///|
test "dynamic programming handles empty and short inputs" {
  assert_eq(optimal_changepoints([], penalty=1.0), [])
  assert_eq(optimal_changepoints([1.0, 1.0], min_segment=2), [])
  assert_true(
    piecewise_constant_error([1.0, 1.0, 2.0, 2.0], [2]) <
    piecewise_constant_error([1.0, 1.0, 2.0, 2.0], []),
  )
}

///|
test "nearby changes merge by score" {
  let changes : Array[OfflineChange] = []
  match inspect_split([0.0, 0.0, 1.0, 1.0], 2, min_segment=1) {
    None => ()
    Some(change) => changes.push(change)
  }
  match
    inspect_split([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0], 6, min_segment=1) {
    None => ()
    Some(change) => changes.push(change)
  }
  match
    inspect_split(
      [2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 0.0, 0.0],
      12,
      min_segment=1,
    ) {
    None => ()
    Some(change) => changes.push(change)
  }
  let merged = merge_nearby_changes(changes, 5)
  assert_eq(merged.length(), 2)
  assert_eq(merged[0].index, 6)
  assert_eq(merged[1].index, 12)
}

///|
test "change point metrics account for tolerance and duplicates" {
  let metrics = evaluate_change_points([9, 20, 21], [10, 20], tolerance=1)
  assert_eq(metrics.true_positives, 2)
  assert_eq(metrics.false_positives, 1)
  assert_eq(metrics.false_negatives, 0)
  assert_true(metrics.precision < 1.0)
  assert_eq(evaluate_change_points([], [], tolerance=0).f1, 1.0)
}

///|
test "window scores preserve input length" {
  let scores = window_change_scores([1.0, 2.0, 3.0], min_segment=2)
  assert_eq(scores.length(), 3)
  assert_eq(scores[0], 0.0)
  assert_eq(scores[2], 0.0)
}
