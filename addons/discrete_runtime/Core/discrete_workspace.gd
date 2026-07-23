class_name DiscreteWorkspace
extends RefCounted

const MAX_RUNTIME_CYCLES := 1024

var current_phase_name: StringName = &""
var current_context: Dictionary = {}
var pending_records: Array[ObservationRecord] = []
var observing_records: Array[ObservationRecord] = []
var observed_records: Array[ObservationRecord] = []
var completed_entries: Array[DiscreteEntry] = []
var pending_exit: DiscreteEntry = null
var last_error_message: String = ""
var _settlement_exit: SignalEntry = null

var phase_request_router: DiscretePhaseRequestRouter = null
var operation_router: DiscreteOperationRouter = null
var effect_router: DiscreteEffectRouter = null
var fact_router: DiscreteFactRouter = null
var request_appliers: Array[DiscreteRequestApplier] = []
var effect_appliers: Array[DiscreteEffectApplier] = []
var fact_appliers: Array[DiscreteFactApplier] = []
var operation_processors: Array[DiscreteOperationProcessor] = []
var result_emitters: Array[DiscreteResultEmitter] = []
var runtime_view_attachments: Dictionary = {}

var _runtime: DiscreteRuntime = null
var _seq_counter: int = 0
var _record_order_counter: int = 0

func bind_runtime(runtime: DiscreteRuntime) -> void:
	_runtime = runtime

func reset_runtime() -> void:
	current_phase_name = &""
	current_context = {}
	pending_records.clear()
	observing_records.clear()
	observed_records.clear()
	completed_entries.clear()
	pending_exit = null
	last_error_message = ""
	_settlement_exit = null
	_seq_counter = 0
	_record_order_counter = 0

func begin_phase(phase_name: StringName, context: Dictionary = {}) -> void:
	current_phase_name = phase_name
	current_context = context.duplicate(true)
	pending_records.clear()
	observing_records.clear()
	observed_records.clear()
	completed_entries.clear()
	pending_exit = null
	last_error_message = ""
	_settlement_exit = null

func set_runtime_view_attachments(attachments: Dictionary) -> void:
	runtime_view_attachments = attachments.duplicate()

func next_seq() -> int:
	_seq_counter += 1
	return _seq_counter

func next_record_order() -> int:
	_record_order_counter += 1
	return _record_order_counter

func enqueue_entry(entry: DiscreteEntry) -> void:
	if entry == null:
		return
	_assign_entry_identity(entry)
	var record := ObservationRecord.new().configure(entry, next_record_order())
	pending_records.append(record)

func request_exit(exit_entry: DiscreteEntry) -> void:
	if pending_exit != null or exit_entry == null:
		return
	_assign_entry_identity(exit_entry)
	pending_exit = exit_entry
	completed_entries.append(exit_entry)

func get_runtime_view() -> DiscreteRuntimeView:
	return DiscreteRuntimeView.new().configure(_runtime, self, runtime_view_attachments)

func find_completed_fact(op_name: StringName) -> FactEntry:
	for index in range(completed_entries.size() - 1, -1, -1):
		var entry := completed_entries[index]
		var fact := entry as FactEntry
		if fact != null and fact.op_name == op_name:
			return fact
	return null

func has_active_entries() -> bool:
	return not pending_records.is_empty() or not observing_records.is_empty() or not observed_records.is_empty()

func is_settling_exit() -> bool:
	return _settlement_exit != null

func has_error() -> bool:
	return last_error_message != ""

func get_last_error_message() -> String:
	return last_error_message

func run_until_exit() -> bool:
	var cycle_count := 0
	while cycle_count < MAX_RUNTIME_CYCLES:
		cycle_count += 1

		if has_error():
			return false

		if pending_exit != null:
			return true

		while not pending_records.is_empty():
			_run_observation_round()
			if has_error():
				return false
			if pending_exit != null:
				return true

		if _dispatch_highest_priority_effect_batch():
			continue
		if has_error():
			return false

		if _dispatch_fact_batch():
			continue
		if has_error():
			return false

		if await _dispatch_next_operation():
			continue
		if has_error():
			return false

		if _dispatch_request_batch():
			continue
		if has_error():
			return false

		if _is_stable():
			if _settlement_exit != null:
				request_exit(_settlement_exit)
				_settlement_exit = null
				return true
			if _try_emit_result():
				return true
			_fail("DiscreteWorkspace reached stability without a result in phase: %s" % String(current_phase_name))
			return false

	_fail("DiscreteWorkspace exceeded runtime cycle budget for phase: %s" % String(current_phase_name))
	return false

func complete_record(record: ObservationRecord) -> void:
	if record == null or record.entry == null:
		return
	observed_records.erase(record)
	observing_records.erase(record)
	pending_records.erase(record)
	completed_entries.append(record.entry)
	record.flags[ObservationRecord.FLAG_CONSUMED] = true

func _run_observation_round() -> void:
	var round_records := pending_records.duplicate()
	pending_records.clear()

	for record in round_records:
		if record == null:
			continue
		record.observe_state = ObservationRecord.STATE_OBSERVING
		observing_records.append(record)

	while not observing_records.is_empty():
		var record := observing_records.pop_front() as ObservationRecord
		if record == null or record.entry == null:
			continue
		record.observe_state = ObservationRecord.STATE_OBSERVED
		observed_records.append(record)

		var context := ObservationContext.new().configure(
			current_phase_name,
			_get_window_for_entry(record.entry),
			record.flags,
			record.order,
			get_runtime_view()
		)
		var proposal := _route_record(record, context)
		_apply_proposal(record, proposal)

func _route_record(record: ObservationRecord, context: ObservationContext) -> ObservationProposal:
	if record.entry is PhaseRequestEntry:
		return phase_request_router.route(record.entry as PhaseRequestEntry, context) if phase_request_router != null else ObservationProposal.new()
	if record.entry is OperationEntry:
		return operation_router.route(record.entry as OperationEntry, context) if operation_router != null else ObservationProposal.new()
	if record.entry is EffectEntry:
		return effect_router.route(record.entry as EffectEntry, context) if effect_router != null else ObservationProposal.new()
	if record.entry is FactEntry:
		return fact_router.route(record.entry as FactEntry, context) if fact_router != null else ObservationProposal.new()
	return ObservationProposal.new()

func _apply_proposal(record: ObservationRecord, proposal: ObservationProposal) -> void:
	if proposal == null or record == null:
		return

	for entry in proposal.spawned_entries:
		enqueue_entry(entry)

	if proposal.invalidate_current:
		record.flags[ObservationRecord.FLAG_INVALIDATED] = true

func _collect_observed_records(entry_type: Variant) -> Array[ObservationRecord]:
	var collected: Array[ObservationRecord] = []
	for record in observed_records:
		if record == null or record.entry == null:
			continue
		if is_instance_of(record.entry, entry_type):
			collected.append(record)
	return collected

func _complete_records(records: Array[ObservationRecord]) -> void:
	for record in records:
		complete_record(record)

func _apply_execution_outcome(outcome: ExecutionOutcome) -> bool:
	if outcome == null:
		return false
	var exit_entry := _select_exit_candidate(outcome)
	if exit_entry != null:
		if not outcome.spawned_entries.is_empty():
			_fail("ExecutionOutcome cannot mix exit entries with spawned entries in phase: %s" % String(current_phase_name))
			return false
		var signal_entry := exit_entry as SignalEntry
		if signal_entry != null and signal_entry.exit_mode == SignalEntry.ExitMode.AFTER_SETTLEMENT:
			_request_settlement_exit(signal_entry)
			return false
		if _settlement_exit != null and exit_entry is ResultEntry:
			return false
		request_exit(exit_entry)
		return true
	for entry in outcome.spawned_entries:
		enqueue_entry(entry)
	return false

func _select_exit_candidate(outcome: ExecutionOutcome) -> DiscreteEntry:
	if outcome == null:
		return null
	var signal_candidate: SignalEntry = null
	for signal_entry in outcome.signal_entries:
		if signal_entry == null:
			continue
		_assign_entry_identity(signal_entry)
		if signal_candidate == null or signal_entry.seq < signal_candidate.seq:
			signal_candidate = signal_entry
	if signal_candidate != null:
		return signal_candidate

	var result_candidate: ResultEntry = null
	for result_entry in outcome.result_entries:
		if result_entry == null:
			continue
		_assign_entry_identity(result_entry)
		if result_candidate == null or result_entry.seq < result_candidate.seq:
			result_candidate = result_entry
	if result_candidate != null:
		return result_candidate
	return null

func _request_settlement_exit(signal_entry: SignalEntry) -> void:
	if signal_entry == null:
		return
	_assign_entry_identity(signal_entry)
	if _settlement_exit == null or signal_entry.seq < _settlement_exit.seq:
		_settlement_exit = signal_entry

func _assign_entry_identity(entry: DiscreteEntry) -> void:
	if entry == null:
		return
	if entry.seq <= 0:
		entry.seq = next_seq()
	else:
		_seq_counter = maxi(_seq_counter, entry.seq)
	if entry.id == &"":
		entry.id = StringName("entry_%d" % entry.seq)

func _dispatch_highest_priority_effect_batch() -> bool:
	var effect_records: Array[ObservationRecord] = []
	for record in observed_records:
		if record == null:
			continue
		var effect_entry := record.entry as EffectEntry
		if effect_entry == null:
			continue
		effect_records.append(record)

	if effect_records.is_empty():
		return false

	effect_records.sort_custom(func(a: ObservationRecord, b: ObservationRecord) -> bool:
		var effect_a := a.entry as EffectEntry
		var effect_b := b.entry as EffectEntry
		if effect_a.priority == effect_b.priority:
			return effect_a.seq < effect_b.seq
		return effect_a.priority < effect_b.priority
	)

	var highest_priority := (effect_records[0].entry as EffectEntry).priority
	var batch_records: Array[ObservationRecord] = []
	for record in effect_records:
		var effect_entry := record.entry as EffectEntry
		if effect_entry.priority != highest_priority:
			break
		batch_records.append(record)

	var active_records: Array[ObservationRecord] = []
	for record in batch_records:
		if record.is_invalidated():
			complete_record(record)
			continue
		active_records.append(record)

	if active_records.is_empty():
		return true

	var remaining_records := active_records.duplicate()
	for applier in effect_appliers:
		if applier == null:
			continue
		var handled_entries: Array[EffectEntry] = []
		var handled_records: Array[ObservationRecord] = []
		for record in remaining_records:
			var effect_entry := record.entry as EffectEntry
			if effect_entry != null and applier.can_apply(effect_entry):
				handled_entries.append(effect_entry)
				handled_records.append(record)
		if handled_entries.is_empty():
			continue
		var outcome := applier.apply_batch(self, handled_entries)
		for record in handled_records:
			remaining_records.erase(record)
		_complete_records(handled_records)
		if _apply_execution_outcome(outcome):
			return true

	if not remaining_records.is_empty():
		_fail("DiscreteEffectApplier coverage is incomplete for phase: %s" % String(current_phase_name))
		return false
	return true

func _dispatch_fact_batch() -> bool:
	var fact_records := _collect_observed_records(FactEntry)
	if fact_records.is_empty():
		return false

	var active_records: Array[ObservationRecord] = []
	for record in fact_records:
		if record.is_invalidated():
			complete_record(record)
			continue
		active_records.append(record)

	if active_records.is_empty():
		return true

	var remaining_records := active_records.duplicate()
	for applier in fact_appliers:
		if applier == null:
			continue
		var handled_entries: Array[FactEntry] = []
		var handled_records: Array[ObservationRecord] = []
		for record in remaining_records:
			var fact_entry := record.entry as FactEntry
			if fact_entry != null and applier.can_apply(fact_entry):
				handled_entries.append(fact_entry)
				handled_records.append(record)
		if handled_entries.is_empty():
			continue
		var outcome := applier.apply_batch(self, handled_entries)
		for record in handled_records:
			remaining_records.erase(record)
		_complete_records(handled_records)
		if _apply_execution_outcome(outcome):
			return true

	if not remaining_records.is_empty():
		_fail("DiscreteFactApplier coverage is incomplete for phase: %s" % String(current_phase_name))
		return false
	return true

func _dispatch_next_operation() -> bool:
	for record in observed_records:
		if record == null:
			continue
		var operation_entry := record.entry as OperationEntry
		if operation_entry == null:
			continue
		if record.is_invalidated():
			complete_record(record)
			return true
		for processor in operation_processors:
			if processor == null or not processor.can_process(operation_entry):
				continue
			@warning_ignore("redundant_await")
			var outcome := await processor.process_operation(self, operation_entry)
			complete_record(record)
			_apply_execution_outcome(outcome)
			return true
		_fail("No DiscreteOperationProcessor handled operation: %s" % String(operation_entry.op_name))
		return false
	return false

func _dispatch_request_batch() -> bool:
	var request_records := _collect_observed_records(PhaseRequestEntry)
	if request_records.is_empty():
		return false

	var active_records: Array[ObservationRecord] = []
	for record in request_records:
		if record.is_invalidated():
			complete_record(record)
			continue
		active_records.append(record)

	if active_records.is_empty():
		return true

	var remaining_records := active_records.duplicate()
	for applier in request_appliers:
		if applier == null:
			continue
		var handled_entries: Array[PhaseRequestEntry] = []
		var handled_records: Array[ObservationRecord] = []
		for record in remaining_records:
			var request_entry := record.entry as PhaseRequestEntry
			if request_entry != null and applier.can_apply(request_entry):
				handled_entries.append(request_entry)
				handled_records.append(record)
		if handled_entries.is_empty():
			continue
		var outcome := applier.apply_batch(self, handled_entries)
		for record in handled_records:
			remaining_records.erase(record)
		_complete_records(handled_records)
		if _apply_execution_outcome(outcome):
			return true

	if not remaining_records.is_empty():
		_fail("DiscreteRequestApplier coverage is incomplete for phase: %s" % String(current_phase_name))
		return false
	return true

func _try_emit_result() -> bool:
	for emitter in result_emitters:
		if emitter == null:
			continue
		var result_entry := emitter.emit_result_entry(self)
		if result_entry == null:
			continue
		request_exit(result_entry)
		return true
	return false

func _get_window_for_entry(entry: DiscreteEntry) -> StringName:
	if entry is PhaseRequestEntry:
		return ObservationContext.WINDOW_REQUEST_OBSERVE
	if entry is OperationEntry:
		return ObservationContext.WINDOW_OPERATION_OBSERVE
	if entry is EffectEntry:
		return ObservationContext.WINDOW_EFFECT_OBSERVE
	if entry is FactEntry:
		return ObservationContext.WINDOW_FACT_OBSERVE
	return &""

func _is_stable() -> bool:
	return pending_records.is_empty() and observing_records.is_empty() and observed_records.is_empty()

func _fail(message: String) -> void:
	if last_error_message != "":
		return
	last_error_message = message
	push_error(message)
