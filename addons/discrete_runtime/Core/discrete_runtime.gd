class_name DiscreteRuntime
extends RefCounted

enum Status {
	NOT_STARTED,
	READY,
	ADVANCING,
	EXITED,
	TERMINATED,
	FAILED,
}

var workspace: DiscreteWorkspace = null
var current_phase_name: StringName = &""
var current_context: Dictionary = {}
var current_phase: DiscreteRuntimePhase = null
var pending_exit: DiscreteEntry = null
var phase_registry: Dictionary = {}
var result_interpreters: Array[DiscreteResultInterpreter] = []
var signal_interpreters: Array[DiscreteSignalInterpreter] = []
var is_started: bool = false
var status: int = Status.NOT_STARTED

var _advance_active: bool = false
var _last_error_message: String = ""

func set_workspace(new_workspace: DiscreteWorkspace) -> void:
	workspace = new_workspace
	if workspace != null:
		workspace.bind_runtime(self)

func register_phase(phase: DiscreteRuntimePhase) -> void:
	if phase == null or phase.get_phase_name() == &"":
		return
	phase_registry[phase.get_phase_name()] = phase

func bind_result_interpreters(interpreters: Array[DiscreteResultInterpreter]) -> void:
	result_interpreters = interpreters.duplicate()

func bind_signal_interpreters(interpreters: Array[DiscreteSignalInterpreter]) -> void:
	signal_interpreters = interpreters.duplicate()

func start(initial_phase_name: StringName, context: Dictionary = {}) -> bool:
	if workspace == null:
		_fail_runtime("DiscreteRuntime.start() requires a workspace.")
		return false
	if not phase_registry.has(initial_phase_name):
		_fail_runtime("DiscreteRuntime.start() could not find phase: %s" % String(initial_phase_name))
		return false

	current_phase_name = initial_phase_name
	current_context = context.duplicate(true)
	current_phase = phase_registry.get(initial_phase_name) as DiscreteRuntimePhase
	pending_exit = null
	is_started = true
	status = Status.READY
	_advance_active = false
	_last_error_message = ""
	workspace.reset_runtime()
	return true

func advance() -> bool:
	if _advance_active:
		_reject_concurrent_advance()
		return false
	if status == Status.TERMINATED or status == Status.FAILED:
		return false
	if not is_started:
		_fail_runtime("DiscreteRuntime.advance() requires start() first.")
		return false
	if workspace == null:
		_fail_runtime("DiscreteRuntime.advance() requires a workspace.")
		return false

	_advance_active = true
	status = Status.ADVANCING
	var advanced := await _advance_once()
	_advance_active = false
	return advanced

func _advance_once() -> bool:

	if pending_exit != null:
		var activation_spec := _interpret_pending_exit()
		if activation_spec == null:
			if status == Status.FAILED:
				return false
			pending_exit = null
			current_phase = null
			is_started = false
			status = Status.TERMINATED
			return false
		if not _activate_phase(activation_spec):
			return false

	if current_phase == null:
		_fail_runtime("DiscreteRuntime.advance() has no current phase.")
		return false

	workspace.begin_phase(current_phase_name, current_context)
	current_phase.activate(workspace, current_context)
	if not await workspace.run_until_exit():
		_fail_runtime(workspace.get_last_error_message())
		return false

	pending_exit = workspace.pending_exit
	if pending_exit == null:
		_fail_runtime("DiscreteRuntime.advance() completed without a pending exit.")
		return false
	status = Status.EXITED
	return true

func get_pending_exit() -> DiscreteEntry:
	return pending_exit

func get_last_error_message() -> String:
	if _last_error_message != "":
		return _last_error_message
	if workspace == null:
		return ""
	return workspace.get_last_error_message()

func get_status() -> int:
	return status

func is_advancing() -> bool:
	return _advance_active

func _activate_phase(activation_spec: DiscreteRuntimeActivationSpec) -> bool:
	if activation_spec == null or activation_spec.phase_name == &"":
		_fail_runtime("DiscreteRuntime received an invalid activation spec.")
		return false
	if not phase_registry.has(activation_spec.phase_name):
		_fail_runtime("DiscreteRuntime could not activate missing phase: %s" % String(activation_spec.phase_name))
		return false

	current_phase_name = activation_spec.phase_name
	current_context = activation_spec.context.duplicate(true)
	current_phase = phase_registry.get(current_phase_name) as DiscreteRuntimePhase
	pending_exit = null
	return true

func _interpret_pending_exit() -> DiscreteRuntimeActivationSpec:
	if pending_exit is ResultEntry:
		var result_entry := pending_exit as ResultEntry
		for interpreter in result_interpreters:
			if interpreter == null or not interpreter.can_handle_result(result_entry):
				continue
			return interpreter.interpret_result(result_entry, self, workspace)
		_fail_runtime("No DiscreteResultInterpreter handled result: %s" % String(result_entry.result_name))
		return null

	if pending_exit is SignalEntry:
		var signal_entry := pending_exit as SignalEntry
		for interpreter in signal_interpreters:
			if interpreter == null or not interpreter.can_handle_signal(signal_entry):
				continue
			return interpreter.interpret_signal(signal_entry, self, workspace)
		_fail_runtime("No DiscreteSignalInterpreter handled signal: %s" % String(signal_entry.signal_name))
		return null

	_fail_runtime("DiscreteRuntime cannot interpret pending exit of unsupported type.")
	return null

func _reject_concurrent_advance() -> void:
	_last_error_message = "DiscreteRuntime.advance() rejected a concurrent advance."
	push_error(_last_error_message)

func _fail_runtime(message: String) -> void:
	if message == "":
		message = "DiscreteRuntime failed without an error message."
	_last_error_message = message
	status = Status.FAILED
	is_started = false
	push_error(message)
