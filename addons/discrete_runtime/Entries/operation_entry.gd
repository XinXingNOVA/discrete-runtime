class_name OperationEntry
extends DiscreteEntry

var op_name: StringName = &""
var executor: StringName = &""
var mode: StringName = &""
var input: Dictionary = {}

func configure(
	new_op_name: StringName,
	new_executor: StringName = &"",
	new_mode: StringName = &"",
	new_input: Dictionary = {},
	new_source: StringName = &"",
	new_provenance: EntryProvenance = null
) -> OperationEntry:
	configure_entry(KIND_OPERATION, new_source, new_provenance)
	op_name = new_op_name
	executor = new_executor
	mode = new_mode
	input = new_input.duplicate(true)
	return self
