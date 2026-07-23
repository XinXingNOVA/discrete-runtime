class_name DiscreteRuntimeActivationSpec
extends RefCounted

var phase_name: StringName = &""
var context: Dictionary = {}
var transition_reason: StringName = &""
var source_exit: DiscreteEntry = null

func configure(
	new_phase_name: StringName,
	new_context: Dictionary = {},
	new_transition_reason: StringName = &"",
	new_source_exit: DiscreteEntry = null
) -> DiscreteRuntimeActivationSpec:
	phase_name = new_phase_name
	context = new_context.duplicate(true)
	transition_reason = new_transition_reason
	source_exit = new_source_exit
	return self
