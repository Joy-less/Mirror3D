extends Camera3D

@export var move_speed: float
@export var turn_speed: float

func _process(delta:float) -> void:
	if Input.is_physical_key_pressed(KEY_W):
		global_position -= global_basis.z.normalized() * delta * move_speed
	if Input.is_physical_key_pressed(KEY_S):
		global_position += global_basis.z.normalized() * delta * move_speed
	if Input.is_physical_key_pressed(KEY_A):
		global_position -= global_basis.x.normalized() * delta * move_speed
	if Input.is_physical_key_pressed(KEY_D):
		global_position += global_basis.x.normalized() * delta * move_speed
	if Input.is_physical_key_pressed(KEY_UP):
		global_rotation += Vector3(1, 0, 0) * delta * turn_speed
	if Input.is_physical_key_pressed(KEY_DOWN):
		global_rotation -= Vector3(1, 0, 0) * delta * turn_speed
	if Input.is_physical_key_pressed(KEY_LEFT):
		global_rotation += Vector3(0, 1, 0) * delta * turn_speed
	if Input.is_physical_key_pressed(KEY_RIGHT):
		global_rotation -= Vector3(0, 1, 0) * delta * turn_speed
	if Input.is_physical_key_pressed(KEY_E):
		global_position += Vector3(0, delta * move_speed, 0)
	if Input.is_physical_key_pressed(KEY_Q):
		global_position -= Vector3(0, delta * move_speed, 0)
