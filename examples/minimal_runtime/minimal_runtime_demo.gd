extends Node


class CounterState extends RefCounted:
	var value: int = 0
	var target: int = 3
	var trace: Array[String] = []


class CounterPhase extends DiscreteRuntimePhase:
	func activate(workspace: DiscreteWorkspace, context: Dictionary) -> void:
		var amount := int(context.get(&"amount", 1))
		workspace.enqueue_entry(
			EffectEntry.new().configure(
				&"increment",
				&"counter",
				[&"counter"],
				{&"amount": amount},
				PackedStringArray(["counter"]),
				0,
				&"minimal_counter_phase",
				EntryProvenance.new().configure(
					&"minimal_counter_phase",
					[],
					&"",
					&"",
					phase_name,
					ObservationContext.WINDOW_EFFECT_OBSERVE
				)
			)
		)


class CounterEffectApplier extends DiscreteEffectApplier:
	var state: CounterState = null

	func can_apply(entry: EffectEntry) -> bool:
		return entry != null and entry.op_name == &"increment"

	func apply_batch(workspace: DiscreteWorkspace, entries: Array[EffectEntry]) -> ExecutionOutcome:
		var outcome := ExecutionOutcome.new()
		for entry in entries:
			if entry == null:
				continue
			var before := state.value
			var amount := int(entry.payload.get(&"amount", 0))
			state.value += amount
			state.trace.append("Effect: %d + %d -> %d" % [before, amount, state.value])
			outcome.add_spawned_entry(
				FactEntry.new().configure(
					&"counter_changed",
					entry.target,
					entry.targets,
					{
						&"before": before,
						&"amount": amount,
						&"after": state.value,
					},
					PackedStringArray(["counter"]),
					&"minimal_counter_applier",
					EntryProvenance.new().configure(
						&"minimal_counter_applier",
						[entry.id],
						entry.id,
						entry.id,
						workspace.current_phase_name,
						ObservationContext.WINDOW_EFFECT_APPLY
					)
				)
			)
		return outcome


class CounterFactApplier extends DiscreteFactApplier:
	var state: CounterState = null

	func can_apply(entry: FactEntry) -> bool:
		return entry != null and entry.op_name == &"counter_changed"

	func apply_batch(_workspace: DiscreteWorkspace, entries: Array[FactEntry]) -> ExecutionOutcome:
		for entry in entries:
			if entry != null:
				state.trace.append("Fact: counter=%d" % int(entry.payload.get(&"after", 0)))
		return ExecutionOutcome.new()


class CounterResultEmitter extends DiscreteResultEmitter:
	var state: CounterState = null

	func emit_result_entry(workspace: DiscreteWorkspace) -> ResultEntry:
		if workspace.has_active_entries() or workspace.pending_exit != null:
			return null
		return ResultEntry.new().configure(
			&"step_complete",
			{&"value": state.value},
			DiscreteEntry.RESULT_TYPE_CONTEXT,
			&"minimal_counter_result_emitter",
			EntryProvenance.new().configure(
				&"minimal_counter_result_emitter",
				[],
				&"",
				&"",
				workspace.current_phase_name,
				ObservationContext.WINDOW_PHASE_FINALIZE
			)
		)


class CounterResultInterpreter extends DiscreteResultInterpreter:
	var state: CounterState = null

	func can_handle_result(result_entry: ResultEntry) -> bool:
		return result_entry != null and result_entry.result_name == &"step_complete"

	func interpret_result(
		_result_entry: ResultEntry,
		_runtime: DiscreteRuntime,
		_workspace: DiscreteWorkspace
	) -> DiscreteRuntimeActivationSpec:
		if state.value >= state.target:
			return null
		return DiscreteRuntimeActivationSpec.new().configure(
			&"count_step",
			{&"amount": 1},
			&"continue_counting"
		)


func _ready() -> void:
	var summary := await run_demo()
	if bool(summary.get(&"success", false)):
		print("Minimal Runtime demo completed: %s" % JSON.stringify(summary))
		get_tree().quit(0)
	else:
		push_error("Minimal Runtime demo failed: %s" % JSON.stringify(summary))
		get_tree().quit(1)


func run_demo(target: int = 3) -> Dictionary:
	var state := CounterState.new()
	state.target = target
	var workspace := DiscreteWorkspace.new()
	workspace.effect_router = DiscreteEffectRouter.new()
	workspace.fact_router = DiscreteFactRouter.new()

	var effect_applier := CounterEffectApplier.new()
	effect_applier.state = state
	workspace.effect_appliers = [effect_applier]
	var fact_applier := CounterFactApplier.new()
	fact_applier.state = state
	workspace.fact_appliers = [fact_applier]
	var result_emitter := CounterResultEmitter.new()
	result_emitter.state = state
	workspace.result_emitters = [result_emitter]

	var runtime := DiscreteRuntime.new()
	runtime.set_workspace(workspace)
	runtime.register_phase(CounterPhase.new(&"count_step"))
	var interpreter := CounterResultInterpreter.new()
	interpreter.state = state
	runtime.bind_result_interpreters([interpreter])

	if not runtime.start(&"count_step", {&"amount": 1}):
		return _summary(runtime, state, false)
	while await runtime.advance():
		pass
	return _summary(
		runtime,
		state,
		runtime.get_status() == DiscreteRuntime.Status.TERMINATED and state.value == target
	)


func _summary(runtime: DiscreteRuntime, state: CounterState, success: bool) -> Dictionary:
	return {
		&"success": success,
		&"value": state.value,
		&"target": state.target,
		&"runtime_status": runtime.get_status(),
		&"runtime_status_name": _status_name(runtime.get_status()),
		&"trace": state.trace.duplicate(),
		&"error": runtime.get_last_error_message(),
	}


func _status_name(runtime_status: int) -> String:
	match runtime_status:
		DiscreteRuntime.Status.NOT_STARTED:
			return "NOT_STARTED"
		DiscreteRuntime.Status.READY:
			return "READY"
		DiscreteRuntime.Status.ADVANCING:
			return "ADVANCING"
		DiscreteRuntime.Status.EXITED:
			return "EXITED"
		DiscreteRuntime.Status.TERMINATED:
			return "TERMINATED"
		DiscreteRuntime.Status.FAILED:
			return "FAILED"
		_:
			return "UNKNOWN"
