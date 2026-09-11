class_name SlimerotInteraction
extends Node2D

signal activated
var prompt := "Interact"
var enabled := true

func is_available(player_position: Vector2) -> bool:
	return enabled and global_position.distance_to(player_position) <= SlimerotBalance.INTERACT_RANGE

func activate(player_position: Vector2) -> bool:
	if not is_available(player_position):
		return false
	activated.emit()
	return true
