///|
/// Replay mode controls whether detector state is allowed to mutate.
pub(all) enum ProductionReplayMode {
  StatefulReplay
  ShadowReplay
  CompareReplay
}

///|
pub fn production_replay_mode_name(mode : ProductionReplayMode) -> String {
  match mode {
    StatefulReplay => "stateful"
    ShadowReplay => "shadow"
    CompareReplay => "compare"
  }
}

///|
/// Replay options for deterministic regression and incident investigation.
pub struct ProductionReplayConfig {
  mode : ProductionReplayMode
  start_timestamp : Int64
  step : Int64
  maximum_points : Int
  compare_tolerance : Double
  include_quiet : Bool
}

///|
pub fn ProductionReplayConfig::new(
  mode? : ProductionReplayMode = StatefulReplay,
  start_timestamp? : Int64 = 0L,
  step? : Int64 = 1L,
  maximum_points? : Int = 100000,
  compare_tolerance? : Double = 1.0e-9,
  include_quiet? : Bool = false,
) -> ProductionReplayConfig {
  {
    mode,
    start_timestamp,
    step: if step < 1L {
      1L
    } else {
      step
    },
    maximum_points: if maximum_points < 1 {
      1
    } else {
      maximum_points
    },
    compare_tolerance: if compare_tolerance < 0.0 {
      0.0
    } else {
      compare_tolerance
    },
    include_quiet,
  }
}

///|
pub fn ProductionReplayConfig::mode(
  self : ProductionReplayConfig,
) -> ProductionReplayMode {
  self.mode
}

///|
pub fn ProductionReplayConfig::start_timestamp(
  self : ProductionReplayConfig,
) -> Int64 {
  self.start_timestamp
}

///|
pub fn ProductionReplayConfig::step(self : ProductionReplayConfig) -> Int64 {
  self.step
}

///|
pub fn ProductionReplayConfig::maximum_points(
  self : ProductionReplayConfig,
) -> Int {
  self.maximum_points
}

///|
pub fn ProductionReplayConfig::compare_tolerance(
  self : ProductionReplayConfig,
) -> Double {
  self.compare_tolerance
}

///|
pub fn ProductionReplayConfig::include_quiet(
  self : ProductionReplayConfig,
) -> Bool {
  self.include_quiet
}

///|
/// One normalized replay output row.
pub struct ProductionReplayObservation {
  index : Int
  timestamp : Int64
  value : Double
  baseline : Double
  result : DetectionResult
  state : ProductionHealthState
  emitted : Bool
}

///|
pub fn ProductionReplayObservation::index(
  self : ProductionReplayObservation,
) -> Int {
  self.index
}

///|
pub fn ProductionReplayObservation::timestamp(
  self : ProductionReplayObservation,
) -> Int64 {
  self.timestamp
}

///|
pub fn ProductionReplayObservation::value(
  self : ProductionReplayObservation,
) -> Double {
  self.value
}

///|
pub fn ProductionReplayObservation::baseline(
  self : ProductionReplayObservation,
) -> Double {
  self.baseline
}

///|
pub fn ProductionReplayObservation::result(
  self : ProductionReplayObservation,
) -> DetectionResult {
  self.result
}

///|
pub fn ProductionReplayObservation::state(
  self : ProductionReplayObservation,
) -> ProductionHealthState {
  self.state
}

///|
pub fn ProductionReplayObservation::emitted(
  self : ProductionReplayObservation,
) -> Bool {
  self.emitted
}

///|
pub fn ProductionReplayObservation::summary(
  self : ProductionReplayObservation,
) -> String {
  self.index.to_string() +
  "," +
  self.timestamp.to_string() +
  "," +
  self.value.to_string() +
  "," +
  self.baseline.to_string() +
  "," +
  self.result.score.to_string() +
  "," +
  self.result.changed.to_string() +
  "," +
  production_health_state_name(self.state) +
  "," +
  self.emitted.to_string()
}

///|
/// Aggregate replay statistics and a deterministic checksum.
pub struct ProductionReplaySummary {
  points : Int
  valid : Int
  invalid : Int
  changes : Int
  emitted : Int
  suppressed : Int
  checksum : Double
  first_change : Int
  mean_score : Double
  maximum_score : Double
  final_state : ProductionHealthState
}

///|
pub fn ProductionReplaySummary::points(self : ProductionReplaySummary) -> Int {
  self.points
}

///|
pub fn ProductionReplaySummary::valid(self : ProductionReplaySummary) -> Int {
  self.valid
}

///|
pub fn ProductionReplaySummary::invalid(self : ProductionReplaySummary) -> Int {
  self.invalid
}

///|
pub fn ProductionReplaySummary::changes(self : ProductionReplaySummary) -> Int {
  self.changes
}

///|
pub fn ProductionReplaySummary::emitted(self : ProductionReplaySummary) -> Int {
  self.emitted
}

///|
pub fn ProductionReplaySummary::suppressed(
  self : ProductionReplaySummary,
) -> Int {
  self.suppressed
}

///|
pub fn ProductionReplaySummary::checksum(
  self : ProductionReplaySummary,
) -> Double {
  self.checksum
}

///|
pub fn ProductionReplaySummary::first_change(
  self : ProductionReplaySummary,
) -> Int {
  self.first_change
}

///|
pub fn ProductionReplaySummary::mean_score(
  self : ProductionReplaySummary,
) -> Double {
  self.mean_score
}

///|
pub fn ProductionReplaySummary::maximum_score(
  self : ProductionReplaySummary,
) -> Double {
  self.maximum_score
}

///|
pub fn ProductionReplaySummary::final_state(
  self : ProductionReplaySummary,
) -> ProductionHealthState {
  self.final_state
}

///|
pub fn ProductionReplaySummary::summary(
  self : ProductionReplaySummary,
) -> String {
  "points=" +
  self.points.to_string() +
  ",valid=" +
  self.valid.to_string() +
  ",invalid=" +
  self.invalid.to_string() +
  ",changes=" +
  self.changes.to_string() +
  ",emitted=" +
  self.emitted.to_string() +
  ",suppressed=" +
  self.suppressed.to_string() +
  ",checksum=" +
  self.checksum.to_string() +
  ",first_change=" +
  self.first_change.to_string() +
  ",mean_score=" +
  self.mean_score.to_string() +
  ",maximum_score=" +
  self.maximum_score.to_string() +
  ",state=" +
  production_health_state_name(self.final_state)
}

///|
/// Runs a configured monitor over a reproducible input signal.
pub struct ProductionReplayRunner {
  config : ProductionReplayConfig
  observations : Array[ProductionReplayObservation]
  mut skipped : Int
}

///|
pub fn ProductionReplayRunner::new(
  config? : ProductionReplayConfig = ProductionReplayConfig::new(),
) -> ProductionReplayRunner {
  { config, observations: [], skipped: 0 }
}

///|
pub fn ProductionReplayRunner::config(
  self : ProductionReplayRunner,
) -> ProductionReplayConfig {
  self.config
}

///|
pub fn ProductionReplayRunner::skipped(self : ProductionReplayRunner) -> Int {
  self.skipped
}

///|
pub fn ProductionReplayRunner::observations(
  self : ProductionReplayRunner,
) -> Array[ProductionReplayObservation] {
  let result : Array[ProductionReplayObservation] = []
  for observation in self.observations {
    result.push(observation)
  }
  result
}

///|
fn production_replay_checksum(
  checksum : Double,
  observation : ProductionReplayObservation,
) -> Double {
  let factor = observation.result.score +
    observation.value * 0.0001 +
    observation.baseline * 0.00001
  let bonus = if observation.result.changed { 0.37 } else { 0.0 }
  let next = checksum * 1.0000003 + factor + bonus
  if next > 1.0e12 {
    next % 1000000007.0
  } else {
    next
  }
}

///|
pub fn ProductionReplayRunner::run(
  self : ProductionReplayRunner,
  monitor : ProductionMonitor,
  points : Array[SignalPoint],
) -> ProductionReplaySummary {
  let limit = self.config.maximum_points()
  let mut checksum = 0.0
  let mut valid = 0
  let mut invalid = 0
  let mut changes = 0
  let mut emitted = 0
  let mut suppressed = 0
  let mut first_change = -1
  let mut score_total = 0.0
  let mut maximum_score = 0.0
  let mut processed = 0
  for point in points {
    if processed >= limit {
      self.skipped += 1
      continue
    }
    processed += 1
    match monitor.update_point(point) {
      None => self.skipped += 1
      Some(event) => {
        let result = event.result()
        if is_finite(point.value) {
          valid += 1
        } else {
          invalid += 1
        }
        if result.changed {
          changes += 1
          if first_change < 0 {
            first_change = processed
          }
          if event.kind() is AlertEmitted {
            emitted += 1
          } else {
            suppressed += 1
          }
        }
        score_total += result.score
        if result.score > maximum_score {
          maximum_score = result.score
        }
        let observation = {
          index: processed,
          timestamp: point.timestamp,
          value: point.value,
          baseline: event.baseline(),
          result,
          state: event.state(),
          emitted: event.kind() is AlertEmitted,
        }
        checksum = production_replay_checksum(checksum, observation)
        if self.config.include_quiet() || result.changed {
          self.observations.push(observation)
        }
      }
    }
  }
  let final_snapshot = monitor.snapshot()
  {
    points: processed,
    valid,
    invalid,
    changes,
    emitted,
    suppressed,
    checksum,
    first_change,
    mean_score: if processed == 0 {
      0.0
    } else {
      score_total / processed.to_double()
    },
    maximum_score,
    final_state: final_snapshot.state(),
  }
}

///|
pub fn ProductionReplayRunner::reset(self : ProductionReplayRunner) -> Unit {
  self.observations.clear()
  self.skipped = 0
}

///|
/// Difference between two deterministic replay results.
pub struct ProductionReplayDifference {
  points_delta : Int
  changes_delta : Int
  emitted_delta : Int
  checksum_delta : Double
  score_delta : Double
  equivalent : Bool
}

///|
pub fn ProductionReplayDifference::from_summaries(
  left : ProductionReplaySummary,
  right : ProductionReplaySummary,
  tolerance? : Double = 1.0e-9,
) -> ProductionReplayDifference {
  let checksum_delta = absolute(left.checksum() - right.checksum())
  let score_delta = absolute(left.mean_score() - right.mean_score())
  {
    points_delta: right.points() - left.points(),
    changes_delta: right.changes() - left.changes(),
    emitted_delta: right.emitted() - left.emitted(),
    checksum_delta,
    score_delta,
    equivalent: left.points() == right.points() &&
    left.changes() == right.changes() &&
    left.emitted() == right.emitted() &&
    checksum_delta <= tolerance &&
    score_delta <= tolerance,
  }
}

///|
pub fn ProductionReplayDifference::points_delta(
  self : ProductionReplayDifference,
) -> Int {
  self.points_delta
}

///|
pub fn ProductionReplayDifference::changes_delta(
  self : ProductionReplayDifference,
) -> Int {
  self.changes_delta
}

///|
pub fn ProductionReplayDifference::emitted_delta(
  self : ProductionReplayDifference,
) -> Int {
  self.emitted_delta
}

///|
pub fn ProductionReplayDifference::checksum_delta(
  self : ProductionReplayDifference,
) -> Double {
  self.checksum_delta
}

///|
pub fn ProductionReplayDifference::score_delta(
  self : ProductionReplayDifference,
) -> Double {
  self.score_delta
}

///|
pub fn ProductionReplayDifference::equivalent(
  self : ProductionReplayDifference,
) -> Bool {
  self.equivalent
}

///|
pub fn ProductionReplayDifference::summary(
  self : ProductionReplayDifference,
) -> String {
  "points_delta=" +
  self.points_delta.to_string() +
  ",changes_delta=" +
  self.changes_delta.to_string() +
  ",emitted_delta=" +
  self.emitted_delta.to_string() +
  ",checksum_delta=" +
  self.checksum_delta.to_string() +
  ",score_delta=" +
  self.score_delta.to_string() +
  ",equivalent=" +
  self.equivalent.to_string()
}

///|
/// Creates sorted points from a deterministic scenario for benchmark harnesses.
pub fn production_scenario_points(
  scenario : SignalScenario,
  start_timestamp? : Int64 = 0L,
  step? : Int64 = 1L,
) -> Array[SignalPoint] {
  let values = generate_signal(scenario)
  let result : Array[SignalPoint] = []
  for i, value in values {
    result.push(
      SignalPoint::new(start_timestamp + step * i.to_int64(), value, sequence=i),
    )
  }
  result
}

///|
/// Computes a stable hash-like checksum over a numeric output series.
pub fn production_values_checksum(values : Array[Double]) -> Double {
  let mut checksum = 17.0
  for i, value in values {
    let safe = if is_finite(value) { value } else { 0.0 }
    checksum = checksum * 31.0 + safe + i.to_double() * 0.000001
    if checksum > 1.0e15 {
      checksum = checksum % 1000000007.0
    }
  }
  checksum
}

///|
pub fn production_observations_csv_header() -> String {
  "index,timestamp,value,baseline,score,changed,state,emitted\n"
}

///|
pub fn production_observations_csv(
  observations : Array[ProductionReplayObservation],
) -> String {
  let mut output = production_observations_csv_header()
  for observation in observations {
    output = output + observation.summary() + "\n"
  }
  output
}
