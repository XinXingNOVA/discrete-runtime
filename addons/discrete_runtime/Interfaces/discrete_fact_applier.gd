class_name DiscreteFactApplier
extends Resource

func can_apply(_entry: FactEntry) -> bool:
	return false

func apply_batch(_workspace: DiscreteWorkspace, _entries: Array[FactEntry]) -> ExecutionOutcome:
	return ExecutionOutcome.new()
