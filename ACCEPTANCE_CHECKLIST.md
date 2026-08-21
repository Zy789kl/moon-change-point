# Project verification checklist

This checklist records reproducible project-quality evidence. Run the commands from the repository root.

## Source and tests

- Production implementation: 68 MoonBit implementation files, 24,462 raw lines, and 20,372 non-blank non-comment lines. The count excludes `_build/` and files ending in `_test.mbt`.
- Test suite: 425 tests passed, 0 failed on the Wasm and Wasm-GC targets locally.
- Latest GitHub CI: Ubuntu, macOS, and Windows all passed the all-target test matrix.
- `moon check --deny-warn --target all`: passed.
- `moon build --target all`: passed.
- `moon fmt --check`: passed.
- `moon info` followed by the generated-interface diff: passed.
- `moon run cmd/main`: passed and reproduces the deterministic results in `BENCHMARK.md`.

## Package and repository

- Module: `Zy789kl/moon-change-point`.
- Published version: `0.3.0` on Mooncakes.
- Default branch: `master` on GitHub and GitLink.
- License: Apache-2.0 in the root `LICENSE` file.
- README and `README.mbt.md` are synchronized and cover positioning, capabilities, installation, CLI usage, architecture, benchmark data, tests, CI, and license.
- CI installs the latest stable MoonBit toolchain and verifies format, warnings, all-target build/test, generated interfaces, and the deterministic benchmark workflow.
