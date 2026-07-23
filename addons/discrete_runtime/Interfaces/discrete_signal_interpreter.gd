class_name DiscreteSignalInterpreter
extends Resource

func can_handle_signal(_signal_entry: SignalEntry) -> bool:
	return false

func interpret_signal(
	_signal_entry: SignalEntry,
	_runtime: DiscreteRuntime,
	_workspace: DiscreteWorkspace
) -> DiscreteRuntimeActivationSpec:
	return null
