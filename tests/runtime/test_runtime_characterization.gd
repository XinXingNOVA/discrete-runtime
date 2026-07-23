extends GutTest


func test_observation_reaches_closure_before_selecting_effect_batch() -> void:
	var trace: Array[String] = []
	var handler := TestDiscreteRuntimeFixtures.SpawnChildEffectHandler.new()
	handler.trace = trace
	handler.trigger_op = &"parent"
	handler.child_op = &"child"
	handler.child_priority = 0
	var applier := TestDiscreteRuntimeFixtures.RecordingEffectApplier.new()
	applier.trace = trace
	var workspace := _effect_workspace(handler, applier)
	workspace.enqueue_entry(_effect(&"parent", 10))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_eq(trace, [
		"observe_effect:parent",
		"observe_effect:child",
		"apply_effect_batch:child",
		"apply_effect_batch:parent",
	])


func test_baseline_treats_smaller_effect_priority_integer_as_earlier() -> void:
	var trace: Array[String] = []
	var applier := TestDiscreteRuntimeFixtures.RecordingEffectApplier.new()
	applier.trace = trace
	var workspace := _effect_workspace(null, applier)
	workspace.enqueue_entry(_effect(&"later", 5))
	workspace.enqueue_entry(_effect(&"earlier", -1))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_eq(trace, [
		"apply_effect_batch:earlier",
		"apply_effect_batch:later",
	])


func test_baseline_batches_equal_priority_effects_in_sequence_order() -> void:
	var trace: Array[String] = []
	var applier := TestDiscreteRuntimeFixtures.RecordingEffectApplier.new()
	applier.trace = trace
	var workspace := _effect_workspace(null, applier)
	workspace.enqueue_entry(_effect(&"first", 2))
	workspace.enqueue_entry(_effect(&"second", 2))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_eq(trace, ["apply_effect_batch:first,second"])


func test_after_settlement_signal_drains_reactions_and_remaining_operations() -> void:
	var trace: Array[String] = []
	var reaction_handler := TestDiscreteRuntimeFixtures.SpawnReactionFromFactHandler.new()
	reaction_handler.trace = trace
	var terminal_applier := TestDiscreteRuntimeFixtures.TerminalFactApplier.new()
	terminal_applier.trace = trace
	var effect_applier := TestDiscreteRuntimeFixtures.RecordingEffectApplier.new()
	effect_applier.trace = trace
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"terminal_fact_characterization")
	workspace.fact_router = DiscreteFactRouter.new()
	workspace.fact_router.handlers = [reaction_handler]
	workspace.effect_router = DiscreteEffectRouter.new()
	workspace.operation_router = DiscreteOperationRouter.new()
	workspace.effect_appliers = [effect_applier]
	workspace.fact_appliers = [terminal_applier]
	var operation_processor := TestDiscreteRuntimeFixtures.ImmediateOperationProcessor.new()
	operation_processor.trace = trace
	workspace.operation_processors = [operation_processor]
	workspace.enqueue_entry(FactEntry.new().configure(&"lethal"))
	workspace.enqueue_entry(OperationEntry.new().configure(&"immediate_operation"))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_true(workspace.pending_exit is SignalEntry)
	assert_eq(trace, [
		"observe_fact:lethal",
		"apply_effect_batch:after_lethal",
		"apply_fact:lethal",
		"process_operation:immediate_operation",
		"apply_effect_batch:from_operation",
	])
	assert_false(workspace.has_active_entries())
	assert_eq(operation_processor.settlement_states, [true])


func test_immediate_signal_still_preempts_remaining_work() -> void:
	var trace: Array[String] = []
	var terminal_applier := TestDiscreteRuntimeFixtures.TerminalFactApplier.new()
	terminal_applier.exit_mode = SignalEntry.ExitMode.IMMEDIATE
	terminal_applier.trace = trace
	var operation_processor := TestDiscreteRuntimeFixtures.ImmediateOperationProcessor.new()
	operation_processor.trace = trace
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"immediate_signal_characterization")
	workspace.fact_router = DiscreteFactRouter.new()
	workspace.operation_router = DiscreteOperationRouter.new()
	workspace.fact_appliers = [terminal_applier]
	workspace.operation_processors = [operation_processor]
	workspace.enqueue_entry(FactEntry.new().configure(&"lethal"))
	workspace.enqueue_entry(OperationEntry.new().configure(&"immediate_operation"))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_true(workspace.pending_exit is SignalEntry)
	assert_eq(trace, ["apply_fact:lethal"])
	assert_true(workspace.has_active_entries())


func test_terminal_interpreter_null_sets_explicit_terminated_status() -> void:
	var workspace := DiscreteWorkspace.new()
	workspace.request_appliers = [TestDiscreteRuntimeFixtures.PassThroughRequestApplier.new()]
	workspace.result_emitters = [DiscretePhaseCompleteResultEmitter.new()]
	var runtime := DiscreteRuntime.new()
	runtime.set_workspace(workspace)
	runtime.register_phase(DiscreteSimplePhase.new(&"terminal_phase"))
	runtime.bind_result_interpreters([TestDiscreteRuntimeFixtures.TerminalResultInterpreter.new()])
	assert_true(runtime.start(&"terminal_phase"))
	assert_eq(runtime.get_status(), DiscreteRuntime.Status.READY)

	var first_advance := await runtime.advance()
	var exit_after_first := runtime.pending_exit
	var status_after_first := runtime.get_status()
	var second_advance := await runtime.advance()

	assert_true(first_advance)
	assert_true(exit_after_first is ResultEntry)
	assert_eq(status_after_first, DiscreteRuntime.Status.EXITED)
	assert_false(second_advance)
	assert_eq(runtime.get_status(), DiscreteRuntime.Status.TERMINATED)
	assert_eq(runtime.get_last_error_message(), "")
	assert_false(runtime.is_started)
	assert_null(runtime.pending_exit)


func test_runtime_reports_failed_start_and_can_be_started_after_configuration_is_fixed() -> void:
	var runtime := DiscreteRuntime.new()
	runtime.set_workspace(DiscreteWorkspace.new())
	assert_eq(runtime.get_status(), DiscreteRuntime.Status.NOT_STARTED)

	assert_false(runtime.start(&"missing_phase"))
	assert_push_error("could not find phase")
	assert_eq(runtime.get_status(), DiscreteRuntime.Status.FAILED)
	assert_string_contains(runtime.get_last_error_message(), "missing_phase")

	runtime.register_phase(DiscreteSimplePhase.new(&"configured_phase"))
	assert_true(runtime.start(&"configured_phase"))
	assert_eq(runtime.get_status(), DiscreteRuntime.Status.READY)
	assert_eq(runtime.get_last_error_message(), "")


func test_baseline_immediate_operation_returns_to_normal_observation_and_dispatch() -> void:
	var trace: Array[String] = []
	var processor := TestDiscreteRuntimeFixtures.ImmediateOperationProcessor.new()
	processor.trace = trace
	var effect_applier := TestDiscreteRuntimeFixtures.RecordingEffectApplier.new()
	effect_applier.trace = trace
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"immediate_operation_characterization")
	workspace.operation_router = DiscreteOperationRouter.new()
	workspace.effect_router = DiscreteEffectRouter.new()
	workspace.operation_processors = [processor]
	workspace.effect_appliers = [effect_applier]
	workspace.result_emitters = [DiscretePhaseCompleteResultEmitter.new()]
	workspace.enqueue_entry(OperationEntry.new().configure(&"immediate_operation"))

	var completed := await workspace.run_until_exit()

	assert_true(completed)
	assert_eq(trace, [
		"process_operation:immediate_operation",
		"apply_effect_batch:from_operation",
	])
	assert_eq(processor.settlement_states, [false])


func test_runtime_rejects_a_concurrent_advance_without_interrupting_the_first() -> void:
	var processor := TestDiscreteRuntimeFixtures.ControlledOperationProcessor.new()
	var workspace := DiscreteWorkspace.new()
	workspace.operation_router = DiscreteOperationRouter.new()
	workspace.operation_processors = [processor]
	var phase := TestDiscreteRuntimeFixtures.OperationPhase.new()
	phase.phase_name = &"operation_phase"
	var runtime := DiscreteRuntime.new()
	runtime.set_workspace(workspace)
	runtime.register_phase(phase)
	assert_true(runtime.start(&"operation_phase"))
	var driver := TestDiscreteRuntimeFixtures.ConcurrentAdvanceDriver.new()

	driver.schedule(runtime, &"first")
	var first_start: int = await processor.operation_call_started
	assert_eq(first_start, 1)
	assert_true(runtime.is_advancing())
	assert_eq(runtime.get_status(), DiscreteRuntime.Status.ADVANCING)
	driver.schedule(runtime, &"second")
	await get_tree().process_frame
	assert_false(driver.results.get(&"second", true))
	assert_push_error("rejected a concurrent advance")
	processor.release_first_call.emit()
	await get_tree().process_frame

	assert_true(driver.results.get(&"first", false))
	assert_eq(processor.invocation_count, 1)
	assert_eq(processor.maximum_active_count, 1)
	assert_eq(driver.completion_order, [&"second", &"first"])
	assert_eq(processor.trace, [
		"operation_start:1",
		"operation_finish:1",
	])
	assert_false(runtime.is_advancing())
	assert_eq(runtime.get_status(), DiscreteRuntime.Status.EXITED)
	assert_string_contains(runtime.get_last_error_message(), "concurrent advance")


func _effect_workspace(
	handler: DiscreteObservationHandler,
	applier: DiscreteEffectApplier
) -> DiscreteWorkspace:
	var workspace := DiscreteWorkspace.new()
	workspace.begin_phase(&"effect_characterization")
	workspace.effect_router = DiscreteEffectRouter.new()
	if handler != null:
		workspace.effect_router.handlers = [handler]
	workspace.effect_appliers = [applier]
	workspace.result_emitters = [DiscretePhaseCompleteResultEmitter.new()]
	return workspace


func _effect(op_name: StringName, priority: int) -> EffectEntry:
	return EffectEntry.new().configure(
		op_name,
		null,
		[],
		{},
		PackedStringArray(),
		priority,
		&"runtime_characterization"
	)
