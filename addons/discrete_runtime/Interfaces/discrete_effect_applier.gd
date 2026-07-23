class_name DiscreteEffectApplier
extends Resource

func can_apply(_entry: EffectEntry) -> bool:
	return false

func apply_batch(_workspace: DiscreteWorkspace, _entries: Array[EffectEntry]) -> ExecutionOutcome:
	return ExecutionOutcome.new()
