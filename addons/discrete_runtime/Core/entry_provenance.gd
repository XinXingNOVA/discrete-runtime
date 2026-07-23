class_name EntryProvenance
extends RefCounted

var producer: StringName = &""
var basis: Array[StringName] = []
var parent_id: StringName = &""
var cause_id: StringName = &""
var phase: StringName = &""
var window: StringName = &""

func configure(
	new_producer: StringName = &"",
	new_basis: Array[StringName] = [],
	new_parent_id: StringName = &"",
	new_cause_id: StringName = &"",
	new_phase: StringName = &"",
	new_window: StringName = &""
) -> EntryProvenance:
	producer = new_producer
	basis = new_basis.duplicate()
	parent_id = new_parent_id
	cause_id = new_cause_id
	phase = new_phase
	window = new_window
	return self

func to_debug_dict() -> Dictionary:
	return {
		&"producer": producer,
		&"basis": basis.duplicate(),
		&"parent_id": parent_id,
		&"cause_id": cause_id,
		&"phase": phase,
		&"window": window,
	}
