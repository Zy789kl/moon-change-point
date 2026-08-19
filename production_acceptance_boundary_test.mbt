///|
test "production contract validates numeric bounds and ordering" {
  let validator = ProductionContractValidator::new()
  let _ = validator.register(
    ProductionContractRule::new(
      "requests",
      minimum=0.0,
      maximum=10.0,
      has_minimum=true,
      has_maximum=true,
      minimum_samples=2,
    ),
  )
  let report = validator.validate_numeric_batch("requests", [10L, 8L, 9L], [
    1.0, 11.0, 2.0,
  ])
  assert_eq(report.checked(), 3)
  assert_true(report.rejected() >= 2)
  assert_true(!report.is_valid())
  assert_true(report.summary().contains("requests"))
}

///|
test "production contract accepts a clean numeric batch" {
  let validator = ProductionContractValidator::new()
  let _ = validator.register(
    ProductionContractRule::new(
      "latency",
      minimum=0.0,
      maximum=1000.0,
      has_minimum=true,
      has_maximum=true,
      minimum_samples=3,
    ),
  )
  let report = validator.validate_numeric_batch("latency", [1L, 2L, 3L], [
    10.0, 11.0, 12.0,
  ])
  assert_eq(report.checked(), 3)
  assert_eq(report.accepted(), 3)
  assert_eq(report.rejected(), 0)
  assert_eq(report.acceptance_rate(), 1.0)
  assert_true(report.monotonic())
}

///|
test "production contract tracks bounded labels" {
  let validator = ProductionContractValidator::new()
  let _ = validator.register(
    ProductionContractRule::new(
      "region",
      field_kind=Label,
      maximum_label_length=5,
      maximum_distinct_values=2,
    ),
  )
  let report = validator.validate_label_batch("region", [1L, 2L, 3L, 4L], [
    "cn", "us", "eu", "",
  ])
  assert_eq(report.checked(), 4)
  assert_eq(report.distinct_count(), 4)
  assert_true(report.rejected() >= 2)
}

///|
test "production contract filtering retains usable values" {
  let validator = ProductionContractValidator::new()
  let _ = validator.register(
    ProductionContractRule::new(
      "cpu",
      minimum=0.0,
      maximum=1.0,
      has_minimum=true,
      has_maximum=true,
    ),
  )
  let (timestamps, values, report) = validator.filter_numeric_batch(
    "cpu",
    [1L, 2L, 3L],
    [0.5, -1.0, 0.8],
  )
  assert_eq(timestamps, [1L, 3L])
  assert_eq(values, [0.5, 0.8])
  assert_true(report.rejected() >= 1)
}

///|
test "production contract helpers handle empty and duplicate inputs" {
  assert_true(production_validate_monotonic_timestamps([]))
  assert_true(production_validate_monotonic_timestamps([1L, 1L, 2L]))
  assert_true(!production_validate_monotonic_timestamps([1L, 0L]))
  assert_eq(production_contract_largest_gap([2L, 5L, 9L]), 4L)
  assert_eq(production_contract_distinct_labels(["a", "a", "b"]), 2)
}

///|
test "production guardrail allows healthy observations" {
  let controller = ProductionGuardrailController::new()
  let _ = controller.register(
    ProductionGuardrailRule::new(
      "error-rate",
      metric=GuardrailErrorRate,
      warning_threshold=0.1,
      blocking_threshold=0.2,
      rollback_threshold=0.4,
      minimum_samples=1,
    ),
  )
  let decision = controller.evaluate(
    ProductionGuardrailObservation::new(
      1L,
      GuardrailErrorRate,
      0.01,
      sample_count=20,
    ),
  )
  assert_true(decision.action() is GuardrailAllow)
  assert_true(!decision.triggered())
  assert_eq(controller.failure_streak(), 0)
}

///|
test "production guardrail escalates consecutive failures" {
  let controller = ProductionGuardrailController::new()
  let _ = controller.register(
    ProductionGuardrailRule::new(
      "latency",
      metric=GuardrailLatency,
      warning_threshold=100.0,
      blocking_threshold=200.0,
      rollback_threshold=300.0,
      minimum_samples=1,
      consecutive_failures=2,
    ),
  )
  let first = controller.evaluate(
    ProductionGuardrailObservation::new(
      1L,
      GuardrailLatency,
      250.0,
      sample_count=2,
    ),
  )
  let second = controller.evaluate(
    ProductionGuardrailObservation::new(
      2L,
      GuardrailLatency,
      250.0,
      sample_count=2,
    ),
  )
  assert_true(first.action() is GuardrailWarn)
  assert_true(second.action() is GuardrailBlock)
  assert_true(controller.is_blocked())
  assert_eq(controller.triggered(), 2)
}

///|
test "production guardrail rejects non-finite observations" {
  let controller = ProductionGuardrailController::new()
  let decision = controller.evaluate(
    ProductionGuardrailObservation::new(1L, GuardrailErrorRate, 0.0 / 0.0),
  )
  assert_true(decision.action() is GuardrailBlock)
  assert_true(controller.is_blocked())
  assert_true(decision.reason().contains("non-finite"))
}

///|
test "production guardrail recovery clears a block" {
  let controller = ProductionGuardrailController::new()
  let _ = controller.register(
    ProductionGuardrailRule::new(
      "quality",
      metric=GuardrailDataQuality,
      direction=GuardrailBelow,
      warning_threshold=0.8,
      blocking_threshold=0.6,
      rollback_threshold=0.4,
      minimum_samples=1,
      consecutive_failures=1,
      recovery_samples=2,
    ),
  )
  let _ = controller.evaluate(
    ProductionGuardrailObservation::new(
      1L,
      GuardrailDataQuality,
      0.2,
      sample_count=2,
    ),
  )
  assert_true(controller.is_blocked())
  let _ = controller.evaluate(
    ProductionGuardrailObservation::new(
      2L,
      GuardrailDataQuality,
      0.95,
      sample_count=2,
    ),
  )
  let _ = controller.evaluate(
    ProductionGuardrailObservation::new(
      3L,
      GuardrailDataQuality,
      0.95,
      sample_count=2,
    ),
  )
  assert_true(!controller.is_blocked())
}

///|
test "rollout plan enforces health and duration gates" {
  let plan = ProductionRolloutPlan::new("canary")
  plan.add_stage(
    ProductionRolloutStage::new(
      "ten-percent",
      exposure=0.1,
      minimum_duration=10L,
      required_health=0.9,
    ),
  )
  plan.add_stage(
    ProductionRolloutStage::new(
      "full",
      exposure=1.0,
      minimum_duration=10L,
      required_health=0.95,
    ),
  )
  assert_eq(plan.validate(), [])
  assert_true(plan.start(100L))
  assert_true(!plan.promote(105L, 1.0))
  assert_true(plan.promote(110L, 1.0))
  assert_eq(plan.active_stage(), 1)
  assert_true(plan.promote(120L, 0.96))
  assert_true(plan.is_completed())
}

///|
test "canary tracker combines guardrail health" {
  let controller = ProductionGuardrailController::new()
  let _ = controller.register(
    ProductionGuardrailRule::new(
      "errors",
      metric=GuardrailErrorRate,
      minimum_samples=1,
    ),
  )
  let plan = ProductionRolloutPlan::new("tracked")
  plan.add_stage(ProductionRolloutStage::new("start", minimum_duration=0L))
  assert_true(plan.start(1L))
  let tracker = ProductionCanaryTracker::new(plan, controller)
  let _ = tracker.observe(
    ProductionGuardrailObservation::new(
      1L,
      GuardrailErrorRate,
      0.0,
      sample_count=1,
    ),
  )
  assert_eq(tracker.observations(), 1)
  assert_eq(tracker.healthy_observations(), 1)
  assert_true(tracker.health() > 0.99)
  assert_true(tracker.try_promote(2L))
}

///|
test "export batch is bounded and de-duplicates records" {
  let batch = ProductionExportBatch::new(capacity=2)
  let first = ProductionExportRecord::new(2L, "latency", 10.0)
  let duplicate = ProductionExportRecord::new(2L, "latency", 11.0)
  let second = ProductionExportRecord::new(1L, "latency", 9.0)
  let third = ProductionExportRecord::new(3L, "latency", 12.0)
  assert_true(batch.add(first))
  assert_true(!batch.add(duplicate))
  assert_true(batch.add(second))
  assert_true(!batch.add(third))
  assert_eq(batch.count(), 2)
  assert_eq(batch.duplicate(), 1)
  assert_eq(batch.rejected(), 1)
  assert_eq(batch.ordered()[0].timestamp(), 1L)
}

///|
test "exporters produce stable csv and json lines" {
  let batch = ProductionExportBatch::new()
  let _ = batch.add(
    ProductionExportRecord::new(
      10L,
      "api,latency",
      42.0,
      baseline=40.0,
      score=0.8,
      health=0.95,
      state="alerting",
      source="test",
    ),
  )
  let csv = ProductionTelemetryExporter::new(
    options=ProductionExportOptions::new(format=ExportCsv),
  ).export_batch(batch)
  assert_true(csv.contains("timestamp,metric,value"))
  assert_true(csv.contains("\"api,latency\""))
  let json = ProductionTelemetryExporter::new(
    options=ProductionExportOptions::new(format=ExportJsonLines),
  ).export_batch(batch)
  assert_true(json.contains("\"metric\":\"api,latency\""))
  assert_true(json.contains("\"score\":0.8"))
}

///|
test "exporter sanitizes prometheus names and summarizes values" {
  let batch = ProductionExportBatch::new()
  let _ = batch.add(ProductionExportRecord::new(1L, "api.latency", 1.0))
  let exporter = ProductionTelemetryExporter::new(
    options=ProductionExportOptions::new(
      format=ExportPrometheus,
      metric_prefix="prod_",
    ),
  )
  let prometheus = exporter.export_batch(batch)
  assert_true(prometheus.contains("moon_change_point_prod_api_latency"))
  assert_true(prometheus.contains("# TYPE"))
  let summary = exporter.export_summary([
    ProductionExportRecord::new(1L, "x", 1.0),
  ])
  assert_true(summary.contains("\"count\":1"))
  assert_true(production_export_validate_metric_name("api.latency"))
  assert_true(!production_export_validate_metric_name("api latency"))
}

///|
test "slo tracker remains healthy for an empty interval" {
  let tracker = ProductionSloTracker::new(
    ProductionSloObjective::new("availability", target=0.99),
  )
  let report = tracker.report()
  assert_true(report.compliance() >= 0.0)
  assert_true(report.compliance() <= 1.0)
  assert_true(report.summary().contains("availability"))
}
