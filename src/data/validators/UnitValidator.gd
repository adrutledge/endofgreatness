class_name UnitValidator
extends RefCounted


func validate(tu: TacticalUnit) -> Dictionary:
	return {"valid": true, "errors": [], "used_tonnage": 0.0, "free_tonnage": 0.0}
