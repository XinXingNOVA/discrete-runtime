class_name DiscretePhaseCompleteResultEmitter
extends DiscreteResultEmitter

func emit_result_entry(workspace: DiscreteWorkspace) -> ResultEntry:
	if workspace.pending_exit != null:
		return null
	if workspace.has_active_entries():
		return null

	var provenance := EntryProvenance.new().configure(
		&"phase_complete_result_emitter",
		[],
		&"",
		&"",
		workspace.current_phase_name,
		ObservationContext.WINDOW_PHASE_FINALIZE
	)
	return ResultEntry.new().configure(
		StringName("%s_complete" % String(workspace.current_phase_name)),
		workspace.current_context,
		DiscreteEntry.RESULT_TYPE_MARKER,
		&"phase_complete_result_emitter",
		provenance
	)
