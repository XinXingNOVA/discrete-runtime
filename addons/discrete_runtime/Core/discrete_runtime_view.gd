class_name DiscreteRuntimeView
extends RefCounted

var runtime: DiscreteRuntime = null
var workspace: DiscreteWorkspace = null
var attachments: Dictionary = {}

func configure(
	new_runtime: DiscreteRuntime,
	new_workspace: DiscreteWorkspace,
	new_attachments: Dictionary = {}
) -> DiscreteRuntimeView:
	runtime = new_runtime
	workspace = new_workspace
	attachments = new_attachments.duplicate()
	return self

func get_current_phase_name() -> StringName:
	if runtime == null:
		return &""
	return runtime.current_phase_name

func get_current_context() -> Dictionary:
	if runtime == null:
		return {}
	return runtime.current_context.duplicate(true)

func get_attachment(key: StringName, default_value: Variant = null) -> Variant:
	return attachments.get(key, default_value)

func find_completed_fact(op_name: StringName) -> FactEntry:
	if workspace == null:
		return null
	return workspace.find_completed_fact(op_name)

func has_pending_exit() -> bool:
	return workspace != null and workspace.pending_exit != null
