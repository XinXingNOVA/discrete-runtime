class_name DiscreteResultInterpreter
extends Resource

func can_handle_result(_result_entry: ResultEntry) -> bool:
	return false

func interpret_result(
	_result_entry: ResultEntry,
	_runtime: DiscreteRuntime,
	_workspace: DiscreteWorkspace
) -> DiscreteRuntimeActivationSpec:
	return null
