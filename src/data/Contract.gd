class_name Contract
extends Resource

var salvage_pool: Array[Dictionary] = []

## Cached tactical engagement data per hex position.
## Key = "q,r" string, value = Dictionary with generated enemy units.
var tactical_cache: Dictionary = {}

@export var issuer: String
@export var target: String
@export var planet: String
@export var activity_type: String
@export var duration: int
@export var salvage_rate: float
@export var salvage_type: String
@export var c_bill_payment: int
@export var transport_coverage: float
@export var base_coverage: float
@export var command_rights: Enums.CommandRights
@export var battle_loss_reimbursement_rate: float
@export var minimum_tonnage: float
@export var minimum_tactical_unit_counts: Dictionary = {}

var payout_per_month: int
var total_paid: int = 0
var is_active: bool = false
var is_completed: bool = false

func meets_minimum_counts(unit_counts: Dictionary) -> Dictionary:
	var shortfalls: Dictionary = {}
	for type_str in minimum_tactical_unit_counts:
		var required: int = minimum_tactical_unit_counts[type_str]
		var available: int = unit_counts.get(type_str, 0)
		if available < required:
			shortfalls[type_str] = required - available
	return shortfalls
