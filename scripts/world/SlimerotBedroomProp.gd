@tool
extends TextureRect
## Reusable 2.5D presentation for existing furniture: a directional floor shadow,
## soft contact occlusion and restrained surface relief. No gameplay or new art.
@export_range(0.05, 0.35) var cast_length := 0.18
@export_range(0.5, 1.0) var footprint_width := 0.82
const SURFACE := preload("res://assets/environment/bedroom/furniture_surface.gdshader")
const SHADOW := preload("res://assets/environment/bedroom/furniture_shadow.gdshader")
var _depth: Node2D
static var _contact_texture: GradientTexture2D

func _ready() -> void:
	if material == null:
		var surface := ShaderMaterial.new()
		surface.shader = SURFACE
		material = surface
	_rebuild_depth()
	if not resized.is_connected(_rebuild_depth): resized.connect(_rebuild_depth)

func _rebuild_depth() -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0: return
	if is_instance_valid(_depth): _depth.free()
	_depth = Node2D.new()
	_depth.name = "FurnitureDepth"
	_depth.z_index = -2
	add_child(_depth, false, Node.INTERNAL_MODE_BACK)
	# Match KEEP_ASPECT_CENTERED, including transparent texture margins.
	var ratio := minf(size.x / texture.get_width(), size.y / texture.get_height())
	var art_size := texture.get_size() * ratio
	var corner := (size - art_size) * 0.5
	var ground := corner + Vector2(art_size.x * 0.5, art_size.y * 0.96)
	if _contact_texture == null:
		_contact_texture = GradientTexture2D.new()
		_contact_texture.width = 128
		_contact_texture.height = 64
		_contact_texture.fill = GradientTexture2D.FILL_RADIAL
		_contact_texture.fill_from = Vector2(0.5, 0.5)
		_contact_texture.fill_to = Vector2(1.0, 0.5)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		gradient.colors = PackedColorArray([Color(0.18, 0.09, 0.06, 0.55), Color(0.18, 0.09, 0.06, 0.38), Color(0.18, 0.09, 0.06, 0.12), Color(0.18, 0.09, 0.06, 0.0)])
		_contact_texture.gradient = gradient
	var cast := Sprite2D.new()
	cast.name = "ProjectedFloorShadow"
	cast.texture = texture
	cast.centered = false
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW
	cast.material = shadow_material
	var shear := 0.20
	cast.transform = Transform2D(Vector2(ratio, 0), Vector2(-ratio * shear, -ratio * cast_length), corner + Vector2(art_size.y * shear, art_size.y * (0.96 + cast_length)))
	_depth.add_child(cast)
	var contact := Sprite2D.new()
	contact.name = "SoftContactShadow"
	contact.texture = _contact_texture
	contact.position = ground + Vector2(0, 2)
	contact.scale = Vector2(art_size.x * footprint_width / 128.0, clampf(art_size.y * 0.17, 22.0, 62.0) / 64.0)
	_depth.add_child(contact)
