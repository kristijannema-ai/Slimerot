class_name SlimerotZone
extends Node2D

@export var zone_id := 0
var obstacles: Array[Rect2] = []
var navigation := AStarGrid2D.new()
var farm_loop := PackedVector2Array([Vector2(500,1150),Vector2(330,1100),Vector2(330,750),Vector2(330,400),Vector2(700,400),Vector2(700,750),Vector2(700,1100),Vector2(500,1150)])

func _ready() -> void:
	if zone_id == 0: return
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
	for y in range(50,1500,50):
		for x in range(50,1000,50):
			var color := Color(colors[1],0.18)
			if zone_id in [2,5,6]: draw_rect(Rect2(x,y,45,45),color,false,1)
			elif zone_id in [4,7]: draw_arc(Vector2(x,y),9,0,PI,12,color,2)
			else: draw_line(Vector2(x,y),Vector2(x+6,y-8),color,2)
	draw_polyline(farm_loop,Color(colors[1],0.55),85,true)
	draw_line(Vector2(500,1360),Vector2(500,210),Color(colors[1],0.7),100)
	for rect in obstacles:
		draw_rect(rect,Color(colors[2]))
		if rect.size.x <= 32 or rect.size.y <= 32: continue
		var center := rect.get_center()
		match zone_id:
			1,3:
				draw_circle(center,rect.size.x*0.48,Color(colors[2]).lightened(0.13))
				draw_line(center,center+Vector2(0,42),Color("40362d"),12)
			2,5:
				draw_colored_polygon(PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),center-Vector2(0,rect.size.y*0.8)]),Color(colors[2]).lightened(0.15))
				draw_rect(Rect2(center-Vector2(15,15),Vector2(30,30)),Color("efd69b"))
			4:
				draw_colored_polygon(PackedVector2Array([rect.position+Vector2(0,rect.size.y),rect.end,center-Vector2(0,rect.size.y*0.5)]),Color("d8b57a"))
			6:
				draw_rect(rect.grow(-10),Color("b4a16a"),false,4)
			7:
				draw_circle(center,rect.size.x*0.38,Color("51566f"))
				draw_arc(center,rect.size.x*0.4,0,TAU,32,Color("b1b4ca"),3)
			8:
				draw_colored_polygon(PackedVector2Array([center-Vector2(0,60),center+Vector2(36,0),center+Vector2(0,50),center-Vector2(36,0)]),Color("b77ce0"))
	draw_rect(Rect2(395,130,210,95),Color("9bac89"))
	draw_rect(Rect2(400,1380,200,70),Color("a6a196"))
	var title := SlimerotCampaign.zone(zone_id).name
	draw_string(ThemeDB.fallback_font,Vector2(270,1260),title,HORIZONTAL_ALIGNMENT_CENTER,460,30,Color("e9f0da"))
	draw_string(ThemeDB.fallback_font,Vector2(290,350),"FARM LOOP  ←    →  MAIN ROUTE",HORIZONTAL_ALIGNMENT_CENTER,420,18,Color("e9f0da"))
