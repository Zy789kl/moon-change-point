// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "hxiuzheng/moon-change-point"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/hxiuzheng/moon-change-point"

license = "Apache-2.0"

keywords = [ "change-point", "anomaly-detection", "time-series", "cusum" ]

preferred_target = "wasm-gc"

description = "MoonBit Online Change Point Detection Library (CUSUM, Page-Hinkley, Bayesian)"
