class_name DiscreteOperationProcessor
extends Resource

func can_process(_entry: OperationEntry) -> bool:
	return false

func process_operation(_workspace: DiscreteWorkspace, _entry: OperationEntry) -> ExecutionOutcome:
	return ExecutionOutcome.new()
