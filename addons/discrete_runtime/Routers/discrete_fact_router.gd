class_name DiscreteFactRouter
extends RefCounted

var handlers: Array[DiscreteObservationHandler] = []

func route(entry: FactEntry, context: ObservationContext) -> ObservationProposal:
	var combined := ObservationProposal.new()
	for handler in handlers:
		if handler == null or not handler.can_handle(entry, context):
			continue
		combined.merge(handler.observe(entry, context))
	return combined
