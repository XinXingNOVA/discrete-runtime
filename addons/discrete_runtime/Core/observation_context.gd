class_name ObservationContext
extends RefCounted

const WINDOW_REQUEST_OBSERVE := &"request_observe"
const WINDOW_OPERATION_OBSERVE := &"operation_observe"
const WINDOW_EFFECT_OBSERVE := &"effect_observe"
const WINDOW_FACT_OBSERVE := &"fact_observe"
const WINDOW_REQUEST_APPLY := &"request_apply"
const WINDOW_OPERATION_APPLY := &"operation_apply"
const WINDOW_EFFECT_APPLY := &"effect_apply"
const WINDOW_FACT_APPLY := &"fact_apply"
const WINDOW_PHASE_FINALIZE := &"phase_finalize"

var phase: StringName = &""
var window: StringName = &""
var flags: Dictionary = {}
var order: int = 0
var runtime_view: DiscreteRuntimeView = null

func configure(
	new_phase: StringName,
	new_window: StringName,
	new_flags: Dictionary,
	new_order: int,
	new_runtime_view: DiscreteRuntimeView
) -> ObservationContext:
	phase = new_phase
	window = new_window
	flags = new_flags
	order = new_order
	runtime_view = new_runtime_view
	return self
