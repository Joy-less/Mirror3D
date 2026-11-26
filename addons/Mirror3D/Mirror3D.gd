@tool
class_name Mirror3D
extends Node3D

@export_group("Camera")
## If valid, this camera will be used as the player camera instead of the active camera.
@export var player_camera_override: Camera3D = null
## The visibility layers rendered by the mirror.
@export_flags_3d_render var cull_mask: int = 0xFFFFF :
	set(value):
		is_config_dirty = true
		cull_mask = value

@export_group("Appearance")
## The size of the mirror quad mesh in units.
@export var size: Vector2 = Vector2(1, 1) :
	set(value):
		is_config_dirty = true
		size = value
## The number of pixels to render per unit.
@export var pixels_per_unit: int = 200 :
	set(value):
		is_config_dirty = true
		pixels_per_unit = value
## If true, uses a linear (anti-aliased) filter; otherwise, uses a nearest (aliased) filter.
@export var use_linear_filter: bool = true :
	set(value):
		is_config_dirty = true
		use_linear_filter = value
## The modulate applied to the mirror.
@export var color: Color = Color(0.9, 0.97, 0.94) :
	set(value):
		is_config_dirty = true
		color = value
## The amount to use the distortion texture.
@export_range(0, 100, 0.01) var distortion: float = 0.0 :
	set(value):
		is_config_dirty = true
		distortion = value
## The noise texture to distort the mirror with.
@export var distortion_texture: Texture2D = null :
	set(value):
		is_config_dirty = true
		distortion_texture = value
## The mask texture the mirror uses.
@export var mask_texture: Texture2D = null :
	set(value):
		is_config_dirty = true
		mask_texture = value

@export_group("Performance")
## The minimum distance of objects in units that the mirror will render.
@export var cull_near: float = 0.05
## The maximum distance of objects in units that the mirror will render.
@export var cull_far: float = 50.0
## The maximum distance of the player camera in units before the mirror is frozen.
@export var freeze_distance: float = 50.0
## The maximum number of mirror updates per second. If negative, unlimited.
@export var max_fps: float = -1.0
## The distance of the player camera in units at which the pixels per unit is halved (with no smooth transition). If negative, resolution falloff is disabled.
@export var halve_resolution_distance: float = 10.0
## The minimum change in the distance of the player camera in units before resolution falloff is updated, to avoid repeated updates when close to the boundaries.
## [br][br]
## [b]Note:[/b] This setting has no effect if [member halve_resolution_distance] is negative.
@export var halve_resolution_hysteresis: float = 0.5
## The minimum resolution in pixels, intended for use with [member halve_resolution_distance].
## [br][br]
## [b]Note:[/b] It's recommended to make this at least 32x32, otherwise SSAO and SSIL may cause errors (see [url]https://github.com/godotengine/godot/issues/86631[/url]).
@export var min_resolution: Vector2i = Vector2i(32, 32) :
	set(value):
		min_resolution = value.max(MINIMUM_VIEWPORT_SIZE)
## Whether to force the mirror to update on the next frame, ignoring [member visible], [member max_fps], and [member freeze_distance].
@export var force_mirror_update_mode: FORCE_MIRROR_UPDATE_MODE = FORCE_MIRROR_UPDATE_MODE.DISABLED

## The viewport used to render the mirror.
@onready var mirror_viewport: SubViewport = $Viewport
## The viewport camera used to sample the mirror.
@onready var mirror_camera: Camera3D = $Viewport/Camera
## The quad mesh instance used to display the mirror.
@onready var mirror_quad: MeshInstance3D = $Quad
## If true, the mirror will be reconfigured on the next frame.
var is_config_dirty: bool = true
## The number of seconds since the mirror was updated.
var time_since_update: float = 0.0
## The distance of the player camera in units during the most recent resolution falloff.
var last_resolution_falloff_distance: float = -1.0

## The possible values for [member force_mirror_update_mode].
enum FORCE_MIRROR_UPDATE_MODE {
	## The mirror will not be forced to update.
	DISABLED = 0,
	## The mirror will be forced to update once, then switch to [constant DISABLED].
	ONCE = 1,
	## The mirror will be forced to update every frame.
	ALWAYS = 2,
}

## The minimum allowed size of a Viewport.
const MINIMUM_VIEWPORT_SIZE: Vector2i = Vector2i(2, 2)

## Updates the mirror.
func _process(delta: float) -> void:
	# Prevent changing the scale, because this breaks the reflection
	var current_scale: Vector3 = Vector3.ONE
	var current_node: Node3D = self
	while is_instance_valid(current_node):
		current_scale *= current_node.scale
		current_node = current_node.get_parent_node_3d()
	if !current_scale.is_finite():
		scale = Vector3.ONE
	elif !current_scale.is_equal_approx(Vector3.ONE):
		scale /= current_scale
	
	# Configure mirror
	if is_config_dirty:
		is_config_dirty = false
		last_resolution_falloff_distance = -1.0
		var viewport_texture: ViewportTexture = mirror_viewport.get_texture()
		var quad_material: ShaderMaterial = mirror_quad.get_active_material(0)
		mirror_camera.cull_mask = cull_mask
		mirror_quad.mesh.size = size
		quad_material.set_shader_parameter(&"color", color)
		quad_material.set_shader_parameter(&"mirror_texture_linear", viewport_texture if use_linear_filter else null)
		quad_material.set_shader_parameter(&"mirror_texture_nearest", viewport_texture if !use_linear_filter else null)
		quad_material.set_shader_parameter(&"use_mirror_texture_linear", use_linear_filter)
		quad_material.set_shader_parameter(&"distortion_texture_linear", distortion_texture if use_linear_filter else null)
		quad_material.set_shader_parameter(&"distortion_texture_nearest", distortion_texture if !use_linear_filter else null)
		quad_material.set_shader_parameter(&"use_distortion_texture_linear", use_linear_filter)
		quad_material.set_shader_parameter(&"distortion_strength", distortion)
		quad_material.set_shader_parameter(&"mask_texture_linear", mask_texture if use_linear_filter else null)
		quad_material.set_shader_parameter(&"mask_texture_nearest", mask_texture if !use_linear_filter else null)
		quad_material.set_shader_parameter(&"use_mask_texture_linear", use_linear_filter)
	
	# Ensure visible
	if !is_visible_in_tree() && force_mirror_update_mode == FORCE_MIRROR_UPDATE_MODE.DISABLED:
		if !_update_resolution_falloff(INF):
			mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	
	# Get player camera viewing mirror
	var player_camera: Camera3D
	if is_instance_valid(player_camera_override):
		player_camera = player_camera_override
	elif Engine.is_editor_hint():
		player_camera = Engine.get_singleton(&"EditorInterface").get_editor_viewport_3d().get_camera_3d()
	else:
		player_camera = get_viewport().get_camera_3d()
	# Ensure player camera exists
	if !is_instance_valid(player_camera):
		if !_update_resolution_falloff(INF):
			mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	
	# Update resolution falloff based on player camera distance
	var player_camera_distance: float = mirror_quad.global_position.distance_to(player_camera.global_position)
	var is_updating_resolution: bool = _update_resolution_falloff(player_camera_distance)
	
	# Freeze mirror if player is far away
	if player_camera_distance >= freeze_distance && force_mirror_update_mode == FORCE_MIRROR_UPDATE_MODE.DISABLED:
		if !is_updating_resolution:
			mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	else:
		if !is_updating_resolution:
			if force_mirror_update_mode != FORCE_MIRROR_UPDATE_MODE.DISABLED:
				mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			else:
				mirror_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	
	# Ensure enough time passed since last update
	if max_fps >= 0.0 && force_mirror_update_mode == FORCE_MIRROR_UPDATE_MODE.DISABLED:
		time_since_update += delta
		if time_since_update < (1.0 / max_fps):
			if !is_updating_resolution:
				mirror_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			return
	if !is_updating_resolution:
		if force_mirror_update_mode != FORCE_MIRROR_UPDATE_MODE.DISABLED:
			mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			mirror_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	time_since_update = 0.0
	
	# Transform mirror camera to opposite side of mirror plane
	var mirror_normal: Vector3 = mirror_quad.global_basis.z
	var mirror_transform: Transform3D = _get_mirror_transform(mirror_normal, mirror_quad.global_position)
	mirror_camera.global_transform = mirror_transform * player_camera.global_transform
	
	# Look perpendicular into mirror plane for frustum camera
	mirror_camera.global_transform = mirror_camera.global_transform.looking_at(
		(mirror_camera.global_position / 2.0) + (player_camera.global_position / 2.0),
		mirror_quad.global_basis.y
	)
	var camera_to_mirror_offset: Vector3 = mirror_quad.global_position - mirror_camera.global_position
	
	# Get near and far cull distances
	var near: float = abs(camera_to_mirror_offset.dot(mirror_normal)) + cull_near
	var far: float = camera_to_mirror_offset.length() + cull_far
	
	# Transform offset to camera's local coordinate system (frustum offset uses local space)
	var cam_to_mirror_offset_camera_local: Vector3 = mirror_camera.global_basis.inverse() * camera_to_mirror_offset
	var frustum_offset: Vector2 = Vector2(cam_to_mirror_offset_camera_local.x, cam_to_mirror_offset_camera_local.y)
	mirror_camera.set_frustum(size.x, frustum_offset, near, far)
	
	# Update force mirror update mode
	if force_mirror_update_mode == FORCE_MIRROR_UPDATE_MODE.ONCE:
		force_mirror_update_mode = FORCE_MIRROR_UPDATE_MODE.DISABLED

## Updates the mirror resolution based on resolution falloff from the player camera distance.
func _update_resolution_falloff(distance: float) -> bool:
	# Calculate resolution falloff based on player camera distance
	var resolution_scale: float = 1.0
	if halve_resolution_distance >= 0.0:
		if last_resolution_falloff_distance < 0.0 || absf(distance - last_resolution_falloff_distance) >= halve_resolution_hysteresis:
			last_resolution_falloff_distance = distance
		resolution_scale = pow(0.5, floorf(last_resolution_falloff_distance / halve_resolution_distance))
	
	# Update mirror resolution
	var scaled_pixels_per_unit: int = roundi(pixels_per_unit * resolution_scale)
	var new_mirror_viewport_size: Vector2i = Vector2i(size * scaled_pixels_per_unit) \
		.max(min_resolution)
	if mirror_viewport.size != new_mirror_viewport_size:
		mirror_viewport.size = new_mirror_viewport_size
		
		# Redraw mirror to avoid appearing completely black
		mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return true
	else:
		return false

## Calculates the transformation that mirrors through the plane with the normal and offset.
static func _get_mirror_transform(normal: Vector3, offset: Vector3) -> Transform3D:
	var basis_x: Vector3 = Vector3(1, 0, 0) - (2 * Vector3(normal.x * normal.x, normal.x * normal.y, normal.x * normal.z))
	var basis_y: Vector3 = Vector3(0, 1, 0) - (2 * Vector3(normal.y * normal.x, normal.y * normal.y, normal.y * normal.z))
	var basis_z: Vector3 = Vector3(0, 0, 1) - (2 * Vector3(normal.z * normal.x, normal.z * normal.y, normal.z * normal.z))
	var origin: Vector3 = 2 * normal.dot(offset) * normal
	return Transform3D(basis_x, basis_y, basis_z, origin)
