class_name MonsterMindEconomySystem
extends Node

var controller: Node

func tick(delta: float) -> void:
	if is_instance_valid(controller):
		controller._update_production(delta)
