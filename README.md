# moon-change-point

面向生产指标的 MoonBit 变点检测库：在线检测、离线分段、迟到数据重排、多变量监控、回放复现、SLO 与告警路由均可组合使用。

## 已实现能力

- CUSUM、Page-Hinkley、简化 BOCPD、EWMA、Robust-Z、IQR、趋势/方差/分布漂移检测。
- 滑动窗口、时间聚合、迟到数据 watermark、批量/流式 pipeline、多指标与多尺度 ensemble。
- 离线 binary segmentation、动态规划、变点评估指标、bootstrap、阈值校准与可解释证据。
- 多变量 Mahalanobis/投影检测，确定性信号生成、回放比较器、CSV/Markdown 输出、SLO、事件聚类和告警预算。

## 安装与最小用法

```text
moon add Zy789kl/moon-change-point
```

```moonbit nocheck
import {
  "Zy789kl/moon-change-point" @cp,
}

fn main {
  let detector = @cp.Cusum::new(target_mean=0.0, control_limit=5.0, drift=0.5)
  let result = detector.update_result(2.0, index=1)
  println(result.summary())
}
```

## 可复现验证

`moon run cmd/main` 输出固定种子、固定 512 点场景的 CUSUM、Robust-Z 与投影 ensemble 基准表。完整测试包含 410 个边界、回归与集成用例；实现源码超过 8,000 行，测试源码独立统计并纳入 CI。

```text
moon fmt --check
moon check --deny-warn --target all
moon test --deny-warn --target all
moon run cmd/main
```

## 许可证与发布

Apache-2.0。Mooncakes 包名为 `Zy789kl/moon-change-point`，源码仓库为 <https://github.com/Zy789kl/moon-change-point>。
