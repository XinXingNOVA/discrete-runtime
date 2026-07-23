class_name ObservationRecord
extends RefCounted

const STATE_PENDING_OBSERVE := &"pending_observe"
const STATE_OBSERVING := &"observing"
const STATE_OBSERVED := &"observed"
const FLAG_INVALIDATED := &"invalidated"
const FLAG_CONSUMED := &"consumed"

var entry: DiscreteEntry = null
var observe_state: StringName = STATE_PENDING_OBSERVE
var flags: Dictionary = {}
var order: int = 0

func configure(new_entry: DiscreteEntry, new_order: int) -> ObservationRecord:
	entry = new_entry
	order = new_order
	observe_state = STATE_PENDING_OBSERVE
	flags = {
		FLAG_INVALIDATED: false,
		FLAG_CONSUMED: false,
	}
	return self

func is_invalidated() -> bool:
	return bool(flags.get(FLAG_INVALIDATED, false))
