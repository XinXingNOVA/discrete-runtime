class_name DiscreteEntry
extends RefCounted

const KIND_PHASE_REQUEST := &"phase_request"
const KIND_OPERATION := &"operation"
const KIND_EFFECT := &"effect"
const KIND_FACT := &"fact"
const KIND_RESULT := &"result"
const KIND_SIGNAL := &"signal"

const RESULT_TYPE_MARKER := &"marker"
const RESULT_TYPE_CONTEXT := &"context"

var id: StringName = &""
var kind: StringName = &""
var source: StringName = &""
var seq: int = 0
var provenance: EntryProvenance = null

func configure_entry(
	new_kind: StringName,
	new_source: StringName = &"",
	new_provenance: EntryProvenance = null
) -> DiscreteEntry:
	kind = new_kind
	source = new_source
	provenance = new_provenance if new_provenance != null else EntryProvenance.new()
	return self

func to_debug_dict() -> Dictionary:
	return {
		&"id": id,
		&"kind": kind,
		&"source": source,
		&"seq": seq,
		&"provenance": provenance.to_debug_dict() if provenance != null else {},
	}
