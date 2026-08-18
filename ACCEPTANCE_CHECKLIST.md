# Hackathon acceptance checklist

## Local evidence

- MoonBit implementation source: 8,600+ lines after formatting; total tracked MoonBit source is 12,000+ lines.
- Test cases: 410 passed, 0 failed.
- `moon check --deny-warn`: passed.
- `moon check --deny-warn --target all`: passed.
- `moon build --target all`: passed.
- `moon test --deny-warn`: passed for wasm and wasm-gc; the local Windows environment does not provide `node.exe`, so the local JS target could not be executed.
- `moon fmt --check`: passed after formatting.
- `moon run cmd/main`: passed and matches `BENCHMARK.md`.

## Repository evidence

- Default branch: `master`.
- License: Apache-2.0.
- Module namespace: `Zy789kl/moon-change-point`.
- GitHub and GitLink remotes are configured.
- Existing and new commits use the repository owner identity; no additional contributor is introduced by this work.
- CI runs the latest stable MoonBit installer on Ubuntu, macOS and Windows, and verifies format, warnings, all-target build/test, generated interfaces and the deterministic benchmark workflow.
