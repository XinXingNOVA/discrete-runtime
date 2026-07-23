extends GutTest


func test_enqueue_assigns_monotonic_identity_and_preserves_provenance() -> void:
	var provenance := EntryProvenance.new().configure(&"producer", [&"basis"])
	var explicit := EffectEntry.new().configure(&"explicit", null, [], {}, PackedStringArray(), 0, &"test", provenance)
	explicit.id = &"preserved_id"
	explicit.seq = 10
	var generated := EffectEntry.new().configure(&"generated")
	var workspace := DiscreteWorkspace.new()

	workspace.enqueue_entry(explicit)
	workspace.enqueue_entry(generated)

	assert_eq(explicit.id, &"preserved_id")
	assert_eq(explicit.seq, 10)
	assert_same(explicit.provenance, provenance)
	assert_eq(generated.seq, 11)
	assert_eq(generated.id, &"entry_11")


func test_reset_runtime_clears_work_and_restarts_generated_sequence() -> void:
	var workspace := DiscreteWorkspace.new()
	var first := EffectEntry.new().configure(&"first")
	workspace.enqueue_entry(first)
	assert_eq(first.seq, 1)

	workspace.reset_runtime()
	assert_false(workspace.has_active_entries())
	assert_true(workspace.completed_entries.is_empty())
	assert_null(workspace.pending_exit)
	var after_reset := EffectEntry.new().configure(&"after_reset")
	workspace.enqueue_entry(after_reset)

	assert_true(workspace.has_active_entries())
	assert_eq(workspace.pending_records.size(), 1)
	assert_eq(after_reset.seq, 1)
	assert_eq(after_reset.id, &"entry_1")


func test_handlers_run_in_registration_order_and_invalidation_blocks_application() -> void:
	var trace: Array[String] = []
	var first := TestDiscreteRuntimeFixtures.TraceObservationHandler.new()
	first.label = "first"
	first.trace = trace
	var second := TestDiscreteRuntimeFixtures.TraceObservationHandler.new()
	second.label = "second"
	second.invalidate_current = true
	second.trace = trace
	var applier := TestDiscreteRuntimeFixtures.LabeledEffectApplier.new()
	applier.trace = trace
	var emitter := TestDiscreteRuntimeFixtures.RecordingResultEmitter.new()
	emitter.result_name = &"complete"
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"invalidation_contract")
	workspace.effect_router = DiscreteEffectRouter.new()
	workspace.effect_router.handlers = [first, second]
	workspace.effect_appliers = [applier]
	workspace.result_emitters = [emitter]
	workspace.enqueue_entry(EffectEntry.new().configure(&"blocked"))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_eq(trace, ["observe:first", "observe:second"])
	assert_true(workspace.pending_exit is ResultEntry)


func test_first_matching_applier_owns_each_effect() -> void:
	var trace: Array[String] = []
	var first := TestDiscreteRuntimeFixtures.LabeledEffectApplier.new()
	first.label = "first"
	first.trace = trace
	var second := TestDiscreteRuntimeFixtures.LabeledEffectApplier.new()
	second.label = "second"
	second.trace = trace
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"applier_order_contract")
	workspace.effect_router = DiscreteEffectRouter.new()
	workspace.effect_appliers = [first, second]
	workspace.result_emitters = [DiscretePhaseCompleteResultEmitter.new()]
	workspace.enqueue_entry(EffectEntry.new().configure(&"owned"))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_eq(trace, ["apply:first:owned"])


func test_incomplete_effect_coverage_is_an_explicit_failure() -> void:
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"coverage_failure_contract")
	workspace.effect_router = DiscreteEffectRouter.new()
	workspace.enqueue_entry(EffectEntry.new().configure(&"unhandled"))

	var completed := await workspace.run_until_exit()

	assert_false(completed)
	assert_push_error("coverage is incomplete")
	assert_string_contains(workspace.get_last_error_message(), "coverage is incomplete")


func test_missing_operation_processor_is_an_explicit_failure() -> void:
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"processor_failure_contract")
	workspace.operation_router = DiscreteOperationRouter.new()
	workspace.enqueue_entry(OperationEntry.new().configure(&"unhandled"))

	var completed := await workspace.run_until_exit()

	assert_false(completed)
	assert_push_error("No DiscreteOperationProcessor")
	assert_string_contains(workspace.get_last_error_message(), "unhandled")


func test_stability_without_result_is_an_explicit_failure() -> void:
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"stability_failure_contract")

	var completed := await workspace.run_until_exit()

	assert_false(completed)
	assert_push_error("reached stability without a result")
	assert_string_contains(workspace.get_last_error_message(), "stability_failure_contract")


func test_outcome_cannot_mix_spawned_work_with_an_exit() -> void:
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"mixed_outcome_contract")
	workspace.effect_router = DiscreteEffectRouter.new()
	workspace.effect_appliers = [TestDiscreteRuntimeFixtures.MixedOutcomeEffectApplier.new()]
	workspace.enqueue_entry(EffectEntry.new().configure(&"mixed"))

	var completed := await workspace.run_until_exit()

	assert_false(completed)
	assert_push_error("cannot mix exit entries with spawned entries")
	assert_string_contains(workspace.get_last_error_message(), "mixed_outcome_contract")


func test_result_emitters_are_queried_in_registration_order() -> void:
	var trace: Array[String] = []
	var empty := TestDiscreteRuntimeFixtures.RecordingResultEmitter.new()
	empty.label = "empty"
	empty.trace = trace
	var selected := TestDiscreteRuntimeFixtures.RecordingResultEmitter.new()
	selected.label = "selected"
	selected.result_name = &"selected_result"
	selected.trace = trace
	var skipped := TestDiscreteRuntimeFixtures.RecordingResultEmitter.new()
	skipped.label = "skipped"
	skipped.result_name = &"skipped_result"
	skipped.trace = trace
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"emitter_order_contract")
	workspace.result_emitters = [empty, selected, skipped]

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_eq(trace, ["emit:empty", "emit:selected"])
	assert_eq((workspace.pending_exit as ResultEntry).result_name, &"selected_result")


func test_deferred_signal_wins_over_a_later_operation_result() -> void:
	var terminal_applier := TestDiscreteRuntimeFixtures.TerminalFactApplier.new()
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"settlement_precedence_contract")
	workspace.fact_router = DiscreteFactRouter.new()
	workspace.operation_router = DiscreteOperationRouter.new()
	workspace.fact_appliers = [terminal_applier]
	workspace.operation_processors = [TestDiscreteRuntimeFixtures.ImmediateResultOperationProcessor.new()]
	workspace.enqueue_entry(FactEntry.new().configure(&"lethal"))
	workspace.enqueue_entry(OperationEntry.new().configure(&"returns_result"))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_true(workspace.pending_exit is SignalEntry)
	assert_eq((workspace.pending_exit as SignalEntry).signal_name, &"terminal")
