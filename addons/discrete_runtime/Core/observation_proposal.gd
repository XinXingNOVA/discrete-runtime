class_name ObservationProposal
extends RefCounted

var spawned_entries: Array[DiscreteEntry] = []
var invalidate_current: bool = false

func add_spawned_entry(entry: DiscreteEntry) -> ObservationProposal:
	if entry != null:
		spawned_entries.append(entry)
	return self

func merge(other: ObservationProposal) -> ObservationProposal:
	if other == null:
		return self
	spawned_entries.append_array(other.spawned_entries)
	invalidate_current = invalidate_current or other.invalidate_current
	return self

func is_empty() -> bool:
	return spawned_entries.is_empty() and not invalidate_current
