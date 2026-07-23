class_name DiscreteRuntimePhase
extends RefCounted

var phase_name: StringName = &""

func _init(new_phase_name: StringName = &"") -> void:
	phase_name = new_phase_name

func get_phase_name() -> StringName:
	return phase_name

func activate(_workspace: DiscreteWorkspace, _context: Dictionary) -> void:
	push_error("DiscreteRuntimePhase.activate() must be overridden for phase: %s" % String(phase_name))
