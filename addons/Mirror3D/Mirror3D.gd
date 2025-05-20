@tool
class_name Mirror3D
extends Node3D

## The size of the mirror quad mesh in units.
@export var size:Vector2 = Vector2(1, 1) :
	set(value):
		config_dirty = true
		size = value
	#end
#end
## The number of pixels to render per unit.
@export var pixels_per_unit:int = 200 :
	set(value):
		config_dirty = true
		pixels_per_unit = value
	#end
#end
## If true, uses a linear (anti-aliased) filter, otherwise, uses a nearest (aliased) filter.
@export var use_linear_filter:bool = true :
	set(value):
		config_dirty = true
		use_linear_filter = value
	#end
#end
## The modulate applied to the mirror.
@export var color:Color = Color(0.9, 0.97, 0.94) :
	set(value):
		config_dirty = true
		color = value
	#end
#end
## The amount to use the distortion texture.
@export_range(0, 100, 0.01) var distortion:float = 0.0 :
	set(value):
		config_dirty = true
		distortion = value
	#end
#end
## The noise texture to distort the mirror with.
@export var distortion_texture:Texture2D = null :
	set(value):
		config_dirty = true
		distortion_texture = value
	#end
#end
## The visibility layers rendered by the mirror.
@export_flags_3d_render var cull_mask:int = 0xFFFFF :
	set(value):
		config_dirty = true
		cull_mask = value
	#end
#end
## The minimum distance of objects the mirror will render.
@export var cull_near:float = 0.05
## The maximum distance of objects the mirror will render.
@export var cull_far:float = 50.0
## The maximum distance of the player camera before the mirror is frozen.
@export var freeze_distance:float = 50.0

## The viewport used to render the mirror.
@onready var mirror_viewport:SubViewport = $Viewport
## The viewport camera used to sample the mirror.
@onready var mirror_camera:Camera3D = $Viewport/Camera
## The quad mesh instance used to display the mirror.
@onready var mirror_quad:MeshInstance3D = $Quad
## If true, the mirror will be reconfigured on the next frame.
var config_dirty:bool = true

## Updates the mirror.
func _process(delta:float)->void:
	# Get player camera viewing mirror
	var player_camera:Camera3D
	if Engine.is_editor_hint():
		player_camera = Engine.get_singleton(&"EditorInterface").get_editor_viewport_3d().get_camera_3d()
	else:
		player_camera = get_viewport().get_camera_3d()
	#end
	# Ensure player camera exists
	if !is_instance_valid(player_camera):
		return
	#end
	
	# Freeze mirror if player is far away
	if global_position.distance_to(player_camera.global_position) >= freeze_distance:
		mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	else:
		mirror_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	#end
	
	# Configure mirror
	if config_dirty:
		config_dirty = false
		var viewport_texture:ViewportTexture = mirror_viewport.get_texture()
		var quad_material:ShaderMaterial = mirror_quad.get_active_material(0)
		mirror_camera.cull_mask = cull_mask
		mirror_quad.mesh.size = size
		mirror_viewport.size = size * pixels_per_unit
		quad_material.set_shader_parameter(&"color", color)
		quad_material.set_shader_parameter(&"distortion_texture", distortion_texture)
		quad_material.set_shader_parameter(&"distortion_strength", distortion)
		quad_material.set_shader_parameter(&"mirror_texture_linear", viewport_texture if use_linear_filter else null)
		quad_material.set_shader_parameter(&"mirror_texture_nearest", viewport_texture if !use_linear_filter else null)
		quad_material.set_shader_parameter(&"use_mirror_texture_linear", use_linear_filter)
	#end
	
	# Transform mirror camera to opposite side of mirror plane
	var mirror_normal:Vector3 = mirror_quad.global_basis.z
	var mirror_transform:Transform3D = get_mirror_transform(mirror_normal, mirror_quad.global_position)
	mirror_camera.global_transform = mirror_transform * player_camera.global_transform
	
	# Look perpendicular into mirror plane for frustum camera
	mirror_camera.global_transform = mirror_camera.global_transform.looking_at(
		(mirror_camera.global_position / 2.0) + (player_camera.global_position / 2.0),
		mirror_quad.global_basis.y
	)
	var camera_to_mirror_offset:Vector3 = mirror_quad.global_position - mirror_camera.global_position
	
	# Get near and far cull distances
	var near:float = abs(camera_to_mirror_offset.dot(mirror_normal)) + cull_near
	var far:float = camera_to_mirror_offset.length() + cull_far
	
	# Transform offset to camera's local coordinate system (frustum offset uses local space)
	var cam_to_mirror_offset_camera_local:Vector3 = mirror_camera.global_basis.inverse() * camera_to_mirror_offset
	var frustum_offset := Vector2(cam_to_mirror_offset_camera_local.x, cam_to_mirror_offset_camera_local.y)
	mirror_camera.set_frustum(size.x, frustum_offset, near, far)
#end

## Calculates the transformation that mirrors through the plane with the normal and offset.
static func get_mirror_transform(normal:Vector3, offset:Vector3)->Transform3D:
	var basis_x:Vector3 = Vector3(1, 0, 0) - (2 * Vector3(normal.x * normal.x, normal.x * normal.y, normal.x * normal.z))
	var basis_y:Vector3 = Vector3(0, 1, 0) - (2 * Vector3(normal.y * normal.x, normal.y * normal.y, normal.y * normal.z))
	var basis_z:Vector3 = Vector3(0, 0, 1) - (2 * Vector3(normal.z * normal.x, normal.z * normal.y, normal.z * normal.z))
	var origin:Vector3 = 2 * normal.dot(offset) * normal
	return Transform3D(basis_x, basis_y, basis_z, origin)
#end
