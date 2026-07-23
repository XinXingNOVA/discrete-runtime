class_name DiscreteRequestApplier
extends Resource

func can_apply(_entry: PhaseRequestEntry) -> bool:
	return false

func apply_batch(_workspace: DiscreteWorkspace, _entries: Array[PhaseRequestEntry]) -> ExecutionOutcome:
	return ExecutionOutcome.new()
