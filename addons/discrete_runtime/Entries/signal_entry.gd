class_name SignalEntry
extends DiscreteEntry

enum ExitMode {
	IMMEDIATE,
	AFTER_SETTLEMENT,
}

var signal_name: StringName = &""
var context: Dictionary = {}
var exit_mode: int = ExitMode.IMMEDIATE

func configure(
	new_signal_name: StringName,
	new_context: Dictionary = {},
	new_source: StringName = &"",
	new_provenance: EntryProvenance = null,
	new_exit_mode: int = ExitMode.IMMEDIATE
) -> SignalEntry:
	configure_entry(KIND_SIGNAL, new_source, new_provenance)
	signal_name = new_signal_name
	context = new_context.duplicate(true)
	exit_mode = new_exit_mode
	return self
