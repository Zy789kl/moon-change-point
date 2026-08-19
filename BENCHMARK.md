# Reproducible benchmark

This benchmark records a reproducible reference workload for `moon-change-point`.

## Fixed workload

- Scenario: deterministic mean + variance shift
- Samples: 512
- Change point: 256
- Baseline: 10.0
- Mean shift: 2.0
- Noise: 0.15 before the change, 0.7 after the change
- Seed: `20260818`
- Command: `moon run cmd/main`

## Detector results

| detector | samples | passes | detections | first detection | precision | recall | F1 | checksum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| cusum | 512 | 512 | 77 | 258 | 0.012987012987012988 | 1 | 0.025641025641025647 | 515.1259371582694 |
| robust-z | 512 | 512 | 11 | 257 | 0.09090909090909091 | 1 | 0.16666666666666669 | 498.5768028924596 |
| projection-ensemble | 512 | 512 | 1 | 257 | 1 | 1 | 1 | 1 |

## Local wall-clock measurement

Machine: Windows local acceptance environment, MoonBit stable toolchain `moon 0.1.20260807`, `moonc v0.10.7`.

Five cold command invocations measured with PowerShell `Measure-Command`:

`246.815 ms, 229.466 ms, 231.101 ms, 247.765 ms, 237.150 ms`

Mean: **238.459 ms**; minimum: **229.466 ms**; maximum: **247.765 ms**.

The timing includes the CLI launch and benchmark program. Detector results and checksums are deterministic; wall-clock values are machine-dependent.
