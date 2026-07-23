class_name DiscreteSimplePhase
extends DiscreteRuntimePhase

func activate(workspace: DiscreteWorkspace, context: Dictionary) -> void:
	var provenance := EntryProvenance.new().configure(
		&"runtime_phase",
		[],
		&"",
		&"",
		phase_name,
		ObservationContext.WINDOW_REQUEST_OBSERVE
	)
	workspace.enqueue_entry(
		PhaseRequestEntry.new().configure(
			phase_name,
			context,
			&"runtime_phase",
			provenance
		)
	)
