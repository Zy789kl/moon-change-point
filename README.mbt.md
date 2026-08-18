# moon-change-point

面向生产指标的 MoonBit 变点检测库：在线检测、离线分段、迟到数据重排、多变量监控、回放复现、SLO 与告警路由均可组合使用。

## 安装与最小用法

```text
moon add Zy789kl/moon-change-point
```

```moonbit nocheck
///|
import {
  "Zy789kl/moon-change-point" @cp,
}

///|
fn main {
  let detector = @cp.Cusum::new(target_mean=0.0, control_limit=5.0, drift=0.5)
  println(detector.update_result(2.0, index=1).summary())
}
```

## 验收验证

固定种子基准可通过 `moon run cmd/main` 重现；项目包含 410 个边界、回归和集成测试，实现源码超过 8,000 行，并在稳定版 MoonBit 的多平台 CI 中执行格式、检查、构建、接口和测试验证。

Apache-2.0。仓库：<https://github.com/Zy789kl/moon-change-point>。
