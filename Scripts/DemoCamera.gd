extends Camera3D

@export var move_speed:float
@export var turn_speed:float

func _process(delta:float)->void:
	if Input.is_physical_key_pressed(KEY_UP) || Input.is_physical_key_pressed(KEY_W):
		global_position -= global_basis.z.normalized() * delta * move_speed
	#end
	if Input.is_physical_key_pressed(KEY_DOWN) || Input.is_physical_key_pressed(KEY_S):
		global_position += global_basis.z.normalized() * delta * move_speed
	#end
	if Input.is_physical_key_pressed(KEY_A):
		global_position -= global_basis.x.normalized() * delta * move_speed
	#end
	if Input.is_physical_key_pressed(KEY_D):
		global_position += global_basis.x.normalized() * delta * move_speed
	#end
	if Input.is_physical_key_pressed(KEY_LEFT):
		rotate_y(delta * turn_speed)
	#end
	if Input.is_physical_key_pressed(KEY_RIGHT):
		rotate_y(-delta * turn_speed)
	#end
	if Input.is_physical_key_pressed(KEY_E):
		global_position += Vector3(0, delta * move_speed, 0)
	#end
	if Input.is_physical_key_pressed(KEY_Q):
		global_position -= Vector3(0, delta * move_speed, 0)
	#end
#end
