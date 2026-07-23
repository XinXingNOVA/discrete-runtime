class_name TestDiscreteRuntimeFixtures
extends RefCounted


class RecordingEffectApplier extends DiscreteEffectApplier:
	var trace: Array[String] = []

	func can_apply(_entry: EffectEntry) -> bool:
		return true

	func apply_batch(_workspace: DiscreteWorkspace, entries: Array[EffectEntry]) -> ExecutionOutcome:
		var names: Array[String] = []
		for entry in entries:
			if entry != null:
				names.append(String(entry.op_name))
		trace.append("apply_effect_batch:%s" % ",".join(names))
		return ExecutionOutcome.new()


class SpawnChildEffectHandler extends DiscreteObservationHandler:
	var trigger_op: StringName = &"parent"
	var child_op: StringName = &"child"
	var child_priority: int = 0
	var trace: Array[String] = []

	func can_handle(entry: DiscreteEntry, _context: ObservationContext) -> bool:
		return entry is EffectEntry

	func observe(entry: DiscreteEntry, _context: ObservationContext) -> ObservationProposal:
		var effect := entry as EffectEntry
		trace.append("observe_effect:%s" % String(effect.op_name))
		var proposal := ObservationProposal.new()
		if effect.op_name == trigger_op:
			proposal.add_spawned_entry(
				EffectEntry.new().configure(
					child_op,
					null,
					[],
					{},
					PackedStringArray(),
					child_priority,
					&"test_spawn_child_handler"
				)
			)
		return proposal


class SpawnReactionFromFactHandler extends DiscreteObservationHandler:
	var trigger_op: StringName = &"lethal"
	var reaction_op: StringName = &"after_lethal"
	var trace: Array[String] = []

	func can_handle(entry: DiscreteEntry, _context: ObservationContext) -> bool:
		return entry is FactEntry

	func observe(entry: DiscreteEntry, _context: ObservationContext) -> ObservationProposal:
		var fact := entry as FactEntry
		trace.append("observe_fact:%s" % String(fact.op_name))
		var proposal := ObservationProposal.new()
		if fact.op_name == trigger_op:
			proposal.add_spawned_entry(
				EffectEntry.new().configure(
					reaction_op,
					null,
					[],
					{},
					PackedStringArray(),
					0,
					&"test_fact_reaction_handler"
				)
			)
		return proposal


class TerminalFactApplier extends DiscreteFactApplier:
	var terminal_op: StringName = &"lethal"
	var exit_mode: int = SignalEntry.ExitMode.AFTER_SETTLEMENT
	var trace: Array[String] = []

	func can_apply(_entry: FactEntry) -> bool:
		return true

	func apply_batch(workspace: DiscreteWorkspace, entries: Array[FactEntry]) -> ExecutionOutcome:
		var outcome := ExecutionOutcome.new()
		for entry in entries:
			if entry == null:
				continue
			trace.append("apply_fact:%s" % String(entry.op_name))
			if entry.op_name == terminal_op:
				outcome.add_signal_entry(
					SignalEntry.new().configure(
						&"terminal",
						{},
						&"test_terminal_fact_applier",
						EntryProvenance.new().configure(
							&"test_terminal_fact_applier",
							[entry.id],
							entry.id,
							entry.id,
							workspace.current_phase_name,
							ObservationContext.WINDOW_FACT_APPLY
						),
						exit_mode
					)
				)
		return outcome


class PassThroughRequestApplier extends DiscreteRequestApplier:
	func can_apply(_entry: PhaseRequestEntry) -> bool:
		return true

	func apply_batch(_workspace: DiscreteWorkspace, _entries: Array[PhaseRequestEntry]) -> ExecutionOutcome:
		return ExecutionOutcome.new()


class TerminalResultInterpreter extends DiscreteResultInterpreter:
	func can_handle_result(_result_entry: ResultEntry) -> bool:
		return true

	func interpret_result(
		_result_entry: ResultEntry,
		_runtime: DiscreteRuntime,
		_workspace: DiscreteWorkspace
	) -> DiscreteRuntimeActivationSpec:
		return null


class OperationPhase extends DiscreteRuntimePhase:
	var operation_name: StringName = &"controlled_operation"

	func activate(workspace: DiscreteWorkspace, _context: Dictionary) -> void:
		workspace.enqueue_entry(
			OperationEntry.new().configure(
				operation_name,
				&"test_processor",
				&"blocking",
				{},
				&"test_operation_phase"
			)
		)


class ImmediateOperationProcessor extends DiscreteOperationProcessor:
	var operation_name: StringName = &"immediate_operation"
	var trace: Array[String] = []
	var settlement_states: Array[bool] = []

	func can_process(entry: OperationEntry) -> bool:
		return entry != null and entry.op_name == operation_name

	func process_operation(workspace: DiscreteWorkspace, entry: OperationEntry) -> ExecutionOutcome:
		settlement_states.append(workspace.is_settling_exit())
		trace.append("process_operation:%s" % String(entry.op_name))
		return ExecutionOutcome.new().add_spawned_entry(
			EffectEntry.new().configure(
				&"from_operation",
				null,
				[],
				{},
				PackedStringArray(),
				0,
				&"test_immediate_processor"
			)
		)


class ControlledOperationProcessor extends DiscreteOperationProcessor:
	signal first_call_started
	signal operation_call_started(call_index: int)
	signal release_first_call

	var operation_name: StringName = &"controlled_operation"
	var invocation_count: int = 0
	var active_count: int = 0
	var maximum_active_count: int = 0
	var trace: Array[String] = []

	func can_process(entry: OperationEntry) -> bool:
		return entry != null and entry.op_name == operation_name

	func process_operation(workspace: DiscreteWorkspace, entry: OperationEntry) -> ExecutionOutcome:
		invocation_count += 1
		var call_index := invocation_count
		active_count += 1
		maximum_active_count = maxi(maximum_active_count, active_count)
		trace.append("operation_start:%d" % call_index)
		operation_call_started.emit(call_index)
		if call_index == 1:
			first_call_started.emit()
			await release_first_call
		trace.append("operation_finish:%d" % call_index)
		active_count -= 1
		return ExecutionOutcome.new().add_result_entry(
			ResultEntry.new().configure(
				&"operation_complete_%d" % call_index,
				{},
				DiscreteEntry.RESULT_TYPE_MARKER,
				&"test_controlled_processor",
				EntryProvenance.new().configure(
					&"test_controlled_processor",
					[entry.id],
					entry.id,
					entry.id,
					workspace.current_phase_name,
					ObservationContext.WINDOW_OPERATION_APPLY
				)
			)
		)


class ConcurrentAdvanceDriver extends RefCounted:
	var results: Dictionary = {}
	var completion_order: Array[StringName] = []

	func schedule(runtime: DiscreteRuntime, label: StringName) -> void:
		call_deferred("_run_advance", runtime, label)

	func _run_advance(runtime: DiscreteRuntime, label: StringName) -> void:
		results[label] = await runtime.advance()
		completion_order.append(label)


class TraceObservationHandler extends DiscreteObservationHandler:
	var label: String = "handler"
	var invalidate_current: bool = false
	var trace: Array[String] = []

	func can_handle(_entry: DiscreteEntry, _context: ObservationContext) -> bool:
		return true

	func observe(_entry: DiscreteEntry, _context: ObservationContext) -> ObservationProposal:
		trace.append("observe:%s" % label)
		var proposal := ObservationProposal.new()
		proposal.invalidate_current = invalidate_current
		return proposal


class LabeledEffectApplier extends DiscreteEffectApplier:
	var label: String = "applier"
	var accepted_op: StringName = &""
	var trace: Array[String] = []

	func can_apply(entry: EffectEntry) -> bool:
		return entry != null and (accepted_op == &"" or entry.op_name == accepted_op)

	func apply_batch(_workspace: DiscreteWorkspace, entries: Array[EffectEntry]) -> ExecutionOutcome:
		var names: Array[String] = []
		for entry in entries:
			if entry != null:
				names.append(String(entry.op_name))
		trace.append("apply:%s:%s" % [label, ",".join(names)])
		return ExecutionOutcome.new()


class MixedOutcomeEffectApplier extends DiscreteEffectApplier:
	func can_apply(_entry: EffectEntry) -> bool:
		return true

	func apply_batch(_workspace: DiscreteWorkspace, _entries: Array[EffectEntry]) -> ExecutionOutcome:
		return ExecutionOutcome.new() \
			.add_spawned_entry(FactEntry.new().configure(&"spawned_fact")) \
			.add_result_entry(ResultEntry.new().configure(&"mixed_result"))


class ImmediateResultOperationProcessor extends DiscreteOperationProcessor:
	func can_process(_entry: OperationEntry) -> bool:
		return true

	func process_operation(_workspace: DiscreteWorkspace, _entry: OperationEntry) -> ExecutionOutcome:
		return ExecutionOutcome.new().add_result_entry(
			ResultEntry.new().configure(&"operation_result")
		)


class RecordingResultEmitter extends DiscreteResultEmitter:
	var label: String = "emitter"
	var result_name: StringName = &""
	var trace: Array[String] = []

	func emit_result_entry(_workspace: DiscreteWorkspace) -> ResultEntry:
		trace.append("emit:%s" % label)
		if result_name == &"":
			return null
		return ResultEntry.new().configure(result_name)
