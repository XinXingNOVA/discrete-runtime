class_name ResultEntry
extends DiscreteEntry

var result_name: StringName = &""
var context: Dictionary = {}
var result_type: StringName = DiscreteEntry.RESULT_TYPE_MARKER

func configure(
	new_result_name: StringName,
	new_context: Dictionary = {},
	new_result_type: StringName = DiscreteEntry.RESULT_TYPE_MARKER,
	new_source: StringName = &"",
	new_provenance: EntryProvenance = null
) -> ResultEntry:
	configure_entry(KIND_RESULT, new_source, new_provenance)
	result_name = new_result_name
	context = new_context.duplicate(true)
	result_type = new_result_type
	return self
