class_name SlimerotZone
extends Node2D

@export var zone_id := 0
var obstacles: Array[Rect2] = []
var navigation := AStarGrid2D.new()
var ground_texture: Texture2D
var environment_textures: Dictionary = {}
var farm_loop := PackedVector2Array([Vector2(500,1150),Vector2(330,1100),Vector2(330,750),Vector2(330,400),Vector2(700,400),Vector2(700,750),Vector2(700,1100),Vector2(500,1150)])

func _ready() -> void:
	if zone_id == 0: return
	ground_texture = SlimerotAssets.zone(zone_id)
	for kind in ["obstacle", "rock", "prop", "border"]:
		environment_textures[kind] = SlimerotAssets.environment(zone_id, kind)
	var title := SlimerotUITheme.world_label(self, Rect2(200, 1210, 600, 68), SlimerotCampaign.zone(zone_id).name, 30)
	title.get_parent().z_index = 2
	var routes := SlimerotUITheme.world_label(self, Rect2(230, 314, 540, 62), "FARM LOOP  ←    →  MAIN ROUTE", 18)
	routes.get_parent().z_index = 2
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	obstacles = [Rect2(0,0,1000,32),Rect2(0,0,32,1500),Rect2(968,0,32,1500),Rect2(0,1468,1000,32),
		Rect2(140,520,110,110),Rect2(770,660,110,110),Rect2(120,280,130,160),Rect2(780,380,100,120),Rect2(120,790,120,120)]
	if zone_id > 1:
		obstacles.append(Rect2(620,850,80,150))
		obstacles.append(Rect2(370,520,90,120))
	for rect in obstacles:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	navigation.region = Rect2i(Vector2i.ZERO,SlimerotCampaign.TILE_COUNT)
	navigation.cell_size = Vector2.ONE * SlimerotCampaign.TILE_SIZE
	navigation.offset = Vector2.ONE * SlimerotCampaign.TILE_SIZE * 0.5
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for x in SlimerotCampaign.TILE_COUNT.x:
		for y in SlimerotCampaign.TILE_COUNT.y:
			var point := Vector2(x*50+25,y*50+25)
			for rect in obstacles:
				if rect.grow(20).has_point(point): navigation.set_point_solid(Vector2i(x,y))
	# Safe Chaser loop and more dangerous inner Shooter/Tank pockets.
	var spawns := [[Vector2(500,900),"chaser"],[Vector2(340,700),"chaser"],[Vector2(710,560),"chaser"],[Vector2(500,380),"chaser"],
		[Vector2(325,1020),"chaser"],[Vector2(720,1120),"chaser"],[Vector2(690,780),"shooter"],[Vector2(280,460),"shooter"],
		[Vector2(830,840),"shooter"],[Vector2(560,640),"tank"],[Vector2(530,1080),"tank"]]
	if zone_id == 1:
		spawns[-1][0] = Vector2(830,1150)
		spawns[4][0] = Vector2(180,1160)
	for row in spawns:
		var enemy := SlimerotEnemy.new()
		enemy.position = row[0]
		enemy.data = SlimerotCampaign.enemy(zone_id,row[1])
		add_child(enemy)

func direction_to_point(origin: Vector2, target: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(origin,target,1)
	if get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return origin.direction_to(target)
	var from := Vector2i(origin/50)
	var to := Vector2i(target/50)
	if not navigation.is_in_boundsv(from) or not navigation.is_in_boundsv(to): return Vector2.ZERO
	if navigation.is_point_solid(from) or navigation.is_point_solid(to): return origin.direction_to(target)
	var path := navigation.get_point_path(from,to)
	return origin.direction_to(path[1]) if path.size() > 1 else Vector2.ZERO

func _draw() -> void:
	if zone_id == 0: return
	var colors: Array = SlimerotCampaign.PALETTES[zone_id-1]
	draw_rect(Rect2(Vector2.ZERO,SlimerotCampaign.SIZE),Color(colors[0]))
	if ground_texture != null:
		draw_texture_rect(ground_texture, Rect2(Vector2.ZERO, SlimerotCampaign.SIZE), true)
	# Quiet paths keep enemy bullets and telegraphs readable. Props are cached
	# textures drawn in one CanvasItem, without one node per decoration.
	draw_polyline(farm_loop,Color(colors[1],0.30),85,true)
	draw_line(Vector2(500,1360),Vector2(500,210),Color(colors[1],0.38),100)
	var obstacle_index := 0
	for rect in obstacles:
		if rect.size.x <= 32 or rect.size.y <= 32:
			draw_environment_border(rect)
			continue
		var kind: String = ["obstacle", "rock", "prop"][obstacle_index % 3]
		var prop := environment_textures.get(kind) as Texture2D
		if prop != null: draw_texture_rect(prop, rect.grow(4), false)
		obstacle_index += 1

func draw_environment_border(rect: Rect2) -> void:
	var border := environment_textures.get("border") as Texture2D
	if border == null: return
	var horizontal := rect.size.x > rect.size.y
	var length := rect.size.x if horizontal else rect.size.y
	# Explicit small tiles preserve the authored silhouette on both axes.
	# This is static geometry and does not create Sprite2D or physics nodes.
	var offset := 0.0
	while offset < length:
		var step := minf(64.0, length - offset)
		var tile := Rect2(rect.position + (Vector2(offset, 0) if horizontal else Vector2(0, offset)), Vector2(step, rect.size.y) if horizontal else Vector2(rect.size.x, step))
		draw_texture_rect(border, tile, false)
		offset += step
