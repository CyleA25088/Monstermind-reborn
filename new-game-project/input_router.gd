class_name MonsterMindInputRouter
extends Node

## Keeps OS/input collection separate from game rules. The controller still
## owns all click behavior; this node only forwards the event.
signal input_received(event: InputEvent)

func _unhandled_input(event: InputEvent) -> void:
	input_received.emit(event)
