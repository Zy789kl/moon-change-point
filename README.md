# moon-change-point

`moon-change-point` is a MoonBit library for online and offline statistical change-point detection in production telemetry and time-series pipelines. It targets WASM, WASM-GC, JavaScript, and native builds through the standard MoonBit toolchain.

## Project positioning

The library provides composable detection primitives for mean shifts, variance changes, spikes, trends, distribution drift, and multivariate changes. It also includes the surrounding data-quality, streaming, evaluation, replay, and alerting utilities needed to move from a detector score to an operational signal.

## Core capabilities

- **Online detection:** CUSUM, Page-Hinkley, simplified Bayesian online detection, EWMA, Robust-Z, IQR, trend, variance, seasonal, rank, and distribution detectors.
- **Streaming pipelines:** bounded windows, time aggregation, watermark-based late-data handling, multi-metric monitoring, suppression, ensembles, and multi-scale evidence.
- **Offline analysis:** binary segmentation, dynamic programming, split inspection, change-point metrics, tolerance-aware evaluation, and piecewise-constant error.
- **Multivariate monitoring:** vector statistics, projection detection, Mahalanobis distance, covariance/correlation analysis, and correlated-change scoring.
- **Operational utilities:** data-quality gates, threshold calibration, bootstrap estimates, deterministic signal generation, replay comparison, explanations, SLO tracking, incident clustering, and alert routing.
- **Output formats:** stable CSV and Markdown reports for logs, notebooks, CI artifacts, and dashboards.

## Quick start

Add the package to a MoonBit module:

```text
moon add Zy789kl/moon-change-point
```

Use a detector through the public package API:

```moonbit nocheck
import {
  "Zy789kl/moon-change-point" @cp,
}

fn main {
  let detector = @cp.Cusum::new(
    target_mean=0.0,
    control_limit=5.0,
    drift=0.5,
  )
  let result = detector.update_result(2.0, index=1)
  println(result.summary())
}
```

`DetectionResult` exposes `changed`, `score`, `confidence`, `direction`, `index`, and `evidence`, so callers can choose their own storage and alerting policy.

## CLI

The repository includes a small reproducible command-line program:

```text
moon run cmd/main
```

It generates a fixed 512-sample mean-and-variance-shift scenario and prints a Markdown benchmark table for CUSUM, Robust-Z, and projection ensemble detection. The library API remains the primary integration surface for applications.

## Architecture

The root package is organized by responsibility:

- `types.mbt`, `stats.mbt`, and `window.mbt` define public results, stable online statistics, and bounded windows.
- `cusum.mbt`, `page_hinkley.mbt`, `bayesian.mbt`, `adaptive_detectors.mbt`, and `advanced_detectors.mbt` implement online detectors.
- `pipeline.mbt`, `stream_engine.mbt`, `time_windows.mbt`, `events.mbt`, and `alert_routing.mbt` compose detectors into streaming workflows.
- `offline_analysis.mbt`, `segment_quality.mbt`, `features.mbt`, and `rank_tests.mbt` provide historical analysis and feature-level evidence.
- `multivariate.mbt`, `matrix.mbt`, and `correlation.mbt` cover vector and cross-series monitoring.
- `quality.mbt`, `calibration.mbt`, `sampling.mbt`, `replay.mbt`, `explainability.mbt`, and `reporting.mbt` support validation, reproducibility, and integration.
- `cmd/main` is a runnable benchmark entry point; it does not add a second library abstraction.

## Benchmark

The benchmark uses a deterministic 512-sample scenario with change point 256, baseline 10.0, mean shift 2.0, pre-change noise 0.15, post-change noise 0.7, and seed `20260818`.

| detector | detections | first detection | precision | recall | F1 |
|---|---:|---:|---:|---:|---:|
| CUSUM | 77 | 258 | 0.012987012987012988 | 1 | 0.025641025641025647 |
| Robust-Z | 11 | 257 | 0.09090909090909091 | 1 | 0.16666666666666669 |
| Projection ensemble | 1 | 257 | 1 | 1 | 1 |

The complete table, checksums, reproduction command, and local wall-clock measurements are in [BENCHMARK.md](BENCHMARK.md).

## Tests

The repository contains boundary, regression, integration, and long-stream tests for the public API:

```text
moon fmt --check
moon check --deny-warn --target all
moon build --target all
moon test --deny-warn --target all
```

The current test suite passes 410 tests. `moon info` regenerates the tracked public interface files so API changes are visible in review.

## CI

GitHub Actions installs the latest stable MoonBit toolchain and runs format, warning-free checks, all-target builds, generated-interface checks, and tests on Ubuntu, macOS, and Windows. The reproducible benchmark workflow runs manually or for version tags.

## License

Apache-2.0. See [LICENSE](LICENSE).

The published package is available as [`Zy789kl/moon-change-point`](https://mooncakes.io/packages/Zy789kl/moon-change-point), and the source repository is [github.com/Zy789kl/moon-change-point](https://github.com/Zy789kl/moon-change-point).
