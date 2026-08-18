///|
test "vector geometry handles empty and unequal vectors" {
  assert_eq(vector_norm([]), 0.0)
  assert_eq(vector_dot([1.0, 2.0], [3.0]), 3.0)
  assert_true(
    absolute(euclidean_distance([0.0, 0.0], [3.0, 4.0]) - 5.0) < 1.0e-12,
  )
  assert_eq(cosine_similarity([0.0], [1.0]), 0.0)
}

///|
test "vector point copies input and validates dimensions" {
  let source = [1.0, 2.0]
  let point = VectorPoint::new(3L, source, sequence=7)
  source[0] = 99.0
  assert_eq(point.values[0], 1.0)
  assert_eq(point.dimension(), 2)
  assert_eq(point.is_valid(), true)
  assert_eq(VectorPoint::new(1L, [0.0 / 0.0]).is_valid(), false)
}

///|
test "online vector stats reject dimension mismatch" {
  let stats = OnlineVectorStats::new(2)
  assert_eq(stats.push([1.0]), false)
  assert_eq(stats.count(), 0)
  assert_eq(stats.push([1.0, 3.0]), true)
  assert_eq(stats.push([2.0, 5.0]), true)
  assert_eq(stats.means(), [1.5, 4.0])
  assert_eq(stats.minimums(), [1.0, 3.0])
  assert_eq(stats.maximums(), [2.0, 5.0])
}

///|
test "mahalanobis detector warms up before scoring" {
  let detector = MahalanobisDetector::new(2, threshold=2.0, warmup=3)
  assert_eq(detector.update([0.0, 0.0]).changed, false)
  assert_eq(detector.update([0.1, -0.1]).changed, false)
  assert_eq(detector.update([0.0, 0.0]).changed, false)
  let result = detector.update([10.0, 10.0])
  assert_eq(direction_name(result.direction), "distribution-shift")
  assert_true(result.score > 1.0)
}

///|
test "projection detector identifies projected drift" {
  let detector = ProjectionDetector::new([1.0, 0.0], threshold=2.0)
  ignore(detector.update([0.0, 0.0]))
  for _ in 0..<5 {
    ignore(detector.update([0.0, 0.0]))
  }
  let result = detector.update([10.0, 0.0])
  assert_true(result.score >= 0.0)
  assert_eq(result.index, 7)
}

///|
test "multivariate ensemble quorum is respected" {
  let ensemble = MultivariateEnsemble::new(
    [
      ProjectionDetector::new([1.0], threshold=1.0),
      ProjectionDetector::new([1.0], threshold=100.0),
    ],
    quorum=2,
  )
  for _ in 0..<3 {
    ignore(ensemble.update([0.0]))
  }
  assert_eq(ensemble.update([5.0]).changed, false)
}

///|
test "diagonal mahalanobis helper is finite" {
  let value = diagonal_mahalanobis([2.0, 4.0], [0.0, 0.0], [1.0, 4.0])
  assert_true(absolute(value - 2.8284271247461903) < 1.0e-9)
}
