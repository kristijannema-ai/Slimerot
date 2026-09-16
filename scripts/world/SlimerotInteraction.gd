class_name SlimerotInteraction
extends Node2D

signal activated
var prompt := "Interact"
var enabled := true
var interaction_in_flight := false

func is_available(player_position: Vector2) -> bool:
	return enabled and global_position.distance_to(player_position) <= SlimerotBalance.INTERACT_RANGE

func activate(player_position: Vector2) -> bool:
	if interaction_in_flight or not is_inside_tree() or not is_available(player_position):
		return false
	interaction_in_flight = true
	activated.emit()
	interaction_in_flight = false
	return true
