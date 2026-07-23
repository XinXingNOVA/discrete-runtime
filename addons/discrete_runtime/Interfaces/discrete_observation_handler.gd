class_name DiscreteObservationHandler
extends Resource

func can_handle(_entry: DiscreteEntry, _context: ObservationContext) -> bool:
	return false

func observe(_entry: DiscreteEntry, _context: ObservationContext) -> ObservationProposal:
	return ObservationProposal.new()
