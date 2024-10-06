extends CharacterBody3D

var motion = Vector3()

const accel = 50
const gravity = 30

var ground_max_speed = 100
var air_max_speed = 100

var swing_point = null
var swing_radius = null

@onready var head: Node3D = $Head
@onready var camera_spring_arm: SpringArm3D = $Head/CameraSpringArm
@onready var hook_line: Node3D = $HookLine
@onready var hook_ray_cast: RayCast3D = $Head/CameraSpringArm/HookRayCast

@onready var target_rotation = rotation
const mouse_sens = 0.2
const max_turn_speed = 0.3


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass
	


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		# We need to rotate the head instead of the entire character.
		camera_spring_arm.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		# clamp locks min/max of a value. Here we use it to make sure we can't look up/down more than 90 degrees
		camera_spring_arm.rotation.x = clamp(camera_spring_arm.rotation.x, deg_to_rad(-90), deg_to_rad(80))

# decelerate movement for when no move key is pressed
func decel(value, delta):
	return lerp(value, 0.0, 1 - pow(0.00001, delta))


func _physics_process(delta: float) -> void:
	# motion is velocity
	motion.y -= gravity * delta
	
	# We handle x and z movement/motion separately in a vector 2d and later on add y and convert to vector 3d
	# x and z are rotated with camera so forward is always in the direction of camera
	var motion_2d = Vector2(motion.x, motion.z).rotated(rotation.y)
	
	var movement_normal = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
		
	motion_2d += movement_normal * accel * delta
	
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			motion.y = 80
		
		if movement_normal.x == 0:
			motion_2d.x = decel(motion_2d.x, delta)
		if movement_normal.y == 0:
			motion_2d.y = decel(motion_2d.y, delta)
			
	
	var max_speed
	if is_on_floor():
		max_speed = ground_max_speed
	else:
		max_speed = air_max_speed
	
	var max_speed_squared = max_speed * max_speed
	
	# comparing squared values is faster for computer
	# This checks if the player's current horizontal speed exceeds the allowed maximum (max_speed).
	if motion_2d.length_squared() > max_speed_squared:
		# This ensures the player continues moving in the same direction, but at the maximum allowed speed, preventing them from exceeding the speed limit.
		# normalized gives the direction of the vector
		motion_2d = motion_2d.normalized() * max_speed
	
	# We rotated the motion based on camera earlier so move inputs are according to camera's facing direction.
	# Now we need to revert the rotate so movement is according to world space.
	motion_2d = motion_2d.rotated(-rotation.y)
	# Here we add a Y access to our motion and make it 3d
	motion = Vector3(motion_2d.x, motion.y, motion_2d.y)
	set_velocity(motion)
	# this tells the physics engine or character controller that the character should always have their "up" oriented along the positive Y-axis.
	set_up_direction(Vector3(0, 1, 0))
	move_and_slide()
	motion = velocity
	
	# Hook section
	handle_hook()
	
	
	
func handle_hook():
	if Input.is_action_just_pressed("hook"):
		if hook_ray_cast.is_colliding():
			print("is colliding")
			swing_point = hook_ray_cast.get_collision_point()
			swing_radius = global_transform.origin.distance_to(swing_point)
	elif Input.is_action_just_released("hook"):
		swing_point = null
	
	if swing_point == null:
		hook_line.hide()
		#camera_3d.target_rotation.z = 0
	else:
		var point_difference = global_transform.origin - swing_point
		var point_distance = point_difference.length()
		
		var point_normal = point_difference.normalized()
		
		
		if point_distance > swing_radius:
			global_transform.origin = swing_point + point_normal * swing_radius
			motion = motion.slide(point_normal)
			
		
		# draw hook line
		hook_line.scale.z = hook_line.global_transform.origin.distance_to(swing_point)
		hook_line.look_at(swing_point, Vector3(0, 1, 0))
		hook_line.show()
		
		#var tilt_scale = point_normal.dot(Vector3(1, 0, 0).rotated(Vector3(1, 0, 0), camera_3d.rotation.x).rotated(Vector3(0, 1, 0), $Camera3D.rotation.y))
		#camera_3d.target_rotation.z = tilt_scale * PI / 8
	
	##hook range indicator
	#if hook_ray_cast.is_colliding():
		#$MeshInstance3D.global_transform.origin = hook_ray_cast.get_collision_point()
		#$MeshInstance3D.show()
	#else:
		#$MeshInstance3D.hide()
