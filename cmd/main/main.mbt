///|
/// Reproducible acceptance benchmark entry point.
fn main {
  println(@cp.benchmark_markdown(@cp.benchmark_suite(rounds=1)))
}
