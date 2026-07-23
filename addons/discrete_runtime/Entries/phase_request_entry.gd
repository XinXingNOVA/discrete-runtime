class_name PhaseRequestEntry
extends DiscreteEntry

var phase_name: StringName = &""
var context: Dictionary = {}

func configure(
	new_phase_name: StringName,
	new_context: Dictionary = {},
	new_source: StringName = &"",
	new_provenance: EntryProvenance = null
) -> PhaseRequestEntry:
	configure_entry(KIND_PHASE_REQUEST, new_source, new_provenance)
	phase_name = new_phase_name
	context = new_context.duplicate(true)
	return self
