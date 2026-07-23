class_name ExecutionOutcome
extends RefCounted

var spawned_entries: Array[DiscreteEntry] = []
var result_entries: Array[ResultEntry] = []
var signal_entries: Array[SignalEntry] = []

func add_spawned_entry(entry: DiscreteEntry) -> ExecutionOutcome:
	if entry != null:
		spawned_entries.append(entry)
	return self

func add_result_entry(entry: ResultEntry) -> ExecutionOutcome:
	if entry != null:
		result_entries.append(entry)
	return self

func add_signal_entry(entry: SignalEntry) -> ExecutionOutcome:
	if entry != null:
		signal_entries.append(entry)
	return self

func merge(other: ExecutionOutcome) -> ExecutionOutcome:
	if other == null:
		return self
	spawned_entries.append_array(other.spawned_entries)
	result_entries.append_array(other.result_entries)
	signal_entries.append_array(other.signal_entries)
	return self

func is_empty() -> bool:
	return spawned_entries.is_empty() and result_entries.is_empty() and signal_entries.is_empty()
