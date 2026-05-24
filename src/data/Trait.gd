class_name CharacterTrait
extends Resource

enum TraitType { POSITIVE, NEGATIVE }

@export var id: String
@export var name: String
@export var description: String
@export var trait_type: TraitType
@export var effect_type: String = ""
@export var effect_value: int = 0
@export var effect_skill: String = ""
