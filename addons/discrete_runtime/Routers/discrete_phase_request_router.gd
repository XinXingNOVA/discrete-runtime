class_name DiscretePhaseRequestRouter
extends RefCounted

var handlers: Array[DiscreteObservationHandler] = []

func route(entry: PhaseRequestEntry, context: ObservationContext) -> ObservationProposal:
	return _route_handlers(entry, context)

func _route_handlers(entry: DiscreteEntry, context: ObservationContext) -> ObservationProposal:
	var combined := ObservationProposal.new()
	for handler in handlers:
		if handler == null or not handler.can_handle(entry, context):
			continue
		combined.merge(handler.observe(entry, context))
	return combined
