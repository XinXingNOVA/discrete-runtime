class_name EffectEntry
extends DiscreteEntry

var op_name: StringName = &""
var target: Variant = null
var targets: Array = []
var payload: Dictionary = {}
var tags: PackedStringArray = PackedStringArray()
var priority: int = 0

func configure(
	new_op_name: StringName,
	new_target: Variant = null,
	new_targets: Array = [],
	new_payload: Dictionary = {},
	new_tags: PackedStringArray = PackedStringArray(),
	new_priority: int = 0,
	new_source: StringName = &"",
	new_provenance: EntryProvenance = null
) -> EffectEntry:
	configure_entry(KIND_EFFECT, new_source, new_provenance)
	op_name = new_op_name
	target = new_target
	targets = new_targets.duplicate(true)
	payload = new_payload.duplicate(true)
	tags = PackedStringArray(new_tags)
	priority = new_priority
	return self
