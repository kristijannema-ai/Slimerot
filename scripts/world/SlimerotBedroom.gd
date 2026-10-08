class_name SlimerotBedroom
extends SlimerotZone
## The existing home scene owns only environment, collision and exit detection.
## World connects the four interaction anchors to the established managers/UI.

signal backyard_requested

## Authored art/physics coordinates remain local; the scene's 0.9 scale makes
## the complete room 10% smaller without scaling the World-owned player or HUD.
const ROOM_SIZE := Vector2(1800, 1620)
const SPAWN_POSITION := Vector2(900, 1100)
const CAMERA_BOTTOM := 2180.0
const NAVIGATION_CELL := Vector2(50, 50)
const NAVIGATION_GRID := Vector2i(36, 33)
const NAVIGATION_CLEARANCE := 20.0 # Player radius stays 19 world pixels.
const ANCHOR_PATHS := {
	"bed": ^"BedArea/InteractionAnchor",
	"collection": ^"CollectionArea/InteractionAnchor",
	"skill_tree_shrine": ^"SkillTreeShrine/InteractionAnchor",
	"sell_terminal": ^"SellTerminal/InteractionAnchor",
	"backyard": ^"BackyardExit/InteractionAnchor",
}
## Public dimensions, spawn and interaction positions use the parent World's
## coordinates, matching World.player.position and World.add_interaction().
var room_size := ROOM_SIZE
## The garden extends below the trigger so the follow camera keeps lower signs
## above the existing mobile controls while approaching the outdoor threshold.
var camera_bottom := CAMERA_BOTTOM
var spawn_position := SPAWN_POSITION
## Collision/navigation data use global physics coordinates, including scale.
var collision_rects: Array[Rect2] = []
var _bound_player: CharacterBody2D
var _exit_requested := false
@onready var exit_trigger: Area2D = $BackyardExit/Trigger

func _ready() -> void:
	zone_id = 0
	room_size = ROOM_SIZE * scale
	spawn_position = transform * SPAWN_POSITION
	camera_bottom = (transform * Vector2(0, CAMERA_BOTTOM)).y
	collision_rects.clear()
	_collect_collision_rects(self)
	obstacles.assign(collision_rects)
	navigation.region = Rect2i(Vector2i.ZERO, NAVIGATION_GRID)
	navigation.cell_size = NAVIGATION_CELL * global_scale.abs()
	navigation.offset = to_global(NAVIGATION_CELL * 0.5)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for x in NAVIGATION_GRID.x:
		for y in NAVIGATION_GRID.y:
			var point := navigation.get_point_position(Vector2i(x, y))
			for rect in collision_rects:
				if rect.grow(NAVIGATION_CLEARANCE).has_point(point):
					navigation.set_point_solid(Vector2i(x, y))
					break

func _collect_collision_rects(branch: Node) -> void:
	for child in branch.get_children():
		if child is CollisionShape2D and child.get_parent() is StaticBody2D and child.shape is RectangleShape2D:
			var shape_rect := Rect2(-child.shape.size * 0.5, child.shape.size)
			collision_rects.append(child.global_transform * shape_rect)
		_collect_collision_rects(child)

func interaction_position(id: String) -> Vector2:
	if not ANCHOR_PATHS.has(id): return spawn_position
	var anchor := get_node(ANCHOR_PATHS[id]) as Node2D
	return (get_parent() as Node2D).to_local(anchor.global_position)

## Convert a global physics point to the scaled grid. The base zone's /50
## indexing is deliberately not used for this compact room's 45-pixel cells.
func navigation_cell(global_point: Vector2) -> Vector2i:
	return Vector2i(((global_point - navigation.offset) / navigation.cell_size + Vector2(0.5, 0.5)).floor())

func direction_to_point(origin: Vector2, target: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(origin, target, 1)
	if get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return origin.direction_to(target)
	var from := navigation_cell(origin)
	var to := navigation_cell(target)
	if not navigation.is_in_boundsv(from) or not navigation.is_in_boundsv(to): return Vector2.ZERO
	if navigation.is_point_solid(from) or navigation.is_point_solid(to): return origin.direction_to(target)
	var path := navigation.get_point_path(from, to)
	return origin.direction_to(path[1]) if path.size() > 1 else Vector2.ZERO

func bind_player(player: CharacterBody2D) -> void:
	_bound_player = player
	_exit_requested = false

func _physics_process(_delta: float) -> void:
	if _exit_requested or not is_instance_valid(_bound_player): return
	if GameState.current_zone != 0 or GameState.is_paused() or GameState.player_dead: return
	# Only deliberate downward movement leaves home. Paused menu overlap or
	# returning from another zone cannot immediately send the player back out.
	if _bound_player.velocity.y <= 0.0 or to_local(_bound_player.global_position).y < 1500.0: return
	if exit_trigger.overlaps_body(_bound_player):
		_exit_requested = true
		_emit_backyard_requested.call_deferred()

func _emit_backyard_requested() -> void:
	if not is_inside_tree() or GameState.current_zone != 0: return
	if GameState.is_paused() or GameState.player_dead:
		_exit_requested = false
		return
	backyard_requested.emit()
