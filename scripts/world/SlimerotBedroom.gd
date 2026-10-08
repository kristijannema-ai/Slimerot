class_name SlimerotBedroom
extends SlimerotZone
## The existing home scene owns only environment, collision and exit detection.
## World connects the four interaction anchors to the established managers/UI.

signal backyard_requested

const ROOM_SIZE := Vector2(1800, 1620)
const SPAWN_POSITION := Vector2(900, 1100)
const ANCHOR_PATHS := {
	"bed": ^"BedArea/InteractionAnchor",
	"collection": ^"CollectionArea/InteractionAnchor",
	"skill_tree_shrine": ^"SkillTreeShrine/InteractionAnchor",
	"sell_terminal": ^"SellTerminal/InteractionAnchor",
	"backyard": ^"BackyardExit/InteractionAnchor",
}
var room_size := ROOM_SIZE
## The garden extends below the trigger so the follow camera keeps lower signs
## above the existing mobile controls while approaching the outdoor threshold.
var camera_bottom := 2180
var spawn_position := SPAWN_POSITION
var collision_rects: Array[Rect2] = []
var _bound_player: CharacterBody2D
var _exit_requested := false
@onready var exit_trigger: Area2D = $BackyardExit/Trigger

func _ready() -> void:
	zone_id = 0
	_collect_collision_rects(self)
	obstacles.assign(collision_rects)
	navigation.region = Rect2i(0, 0, 36, 33)
	navigation.cell_size = Vector2(50, 50)
	navigation.offset = Vector2(25, 25)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for x in 36:
		for y in 33:
			var point := Vector2(x * 50 + 25, y * 50 + 25)
			for rect in collision_rects:
				if rect.grow(20).has_point(point):
					navigation.set_point_solid(Vector2i(x, y))
					break

func _collect_collision_rects(branch: Node) -> void:
	for child in branch.get_children():
		if child is CollisionShape2D and child.get_parent() is StaticBody2D and child.shape is RectangleShape2D:
			collision_rects.append(Rect2(to_local(child.global_position) - child.shape.size * 0.5, child.shape.size))
		_collect_collision_rects(child)

func interaction_position(id: String) -> Vector2:
	if not ANCHOR_PATHS.has(id): return spawn_position
	return to_local((get_node(ANCHOR_PATHS[id]) as Node2D).global_position)

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
