# moon-change-point

MoonBit 在线变点检测库 (Online Change Point Detection Library) - 实现 CUSUM、Page-Hinkley、Bayesian 变点检测和多指标告警抑制，用于发现指标分布、均值或方差的突变。

后续可加入迟到数据处理、变点置信度、分层告警以及实时仪表盘适配。

## Features

- **CUSUM (Cumulative Sum)**: Detects shifts in the mean of a sequence.
- **Page-Hinkley**: Detects sudden changes in signal mean, robust to small noise.
- **Bayesian Online Change Point Detection (BOCPD)**: Uses predictive probability and run-length posterior estimation (simplified Normal-Gamma conjugate prior).
- **Detector Wrapper**: Multi-metric alert suppression to prevent alert fatigue.

## Usage

```moonbit nocheck
import {
  "hxiuzheng/moon-change-point" as cp
}

fn main {
  // Use CUSUM
  let detector = @cp.Detector::new(
    CusumDetector(@cp.Cusum::new(target_mean=0.0, control_limit=5.0, drift=0.5)),
    suppression_limit=3
  )
  
  let _ = detector.update(2.0)
}
```

## License
Apache-2.0