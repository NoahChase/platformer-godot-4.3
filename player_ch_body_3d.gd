extends CharacterBody3D

const SPEED = 3.96 # jump distance of 4 # 3.96
const SPEED_HOVER = 4.43 # used for hover board / slide?
const JUMP_VELOCITY = 4.43 # sintle jump of 1, double of 2 (2.94 double jump)
const JUMP_HOVER_VELOCITY = 8
const MAX_SLOPE_ANGLE = deg_to_rad(16)

enum {FLOOR, AIR, WALL, TO_TARGET, ON_TARGET}

@export var camera_target: Node3D
@export var camera_parent: Node3D
@export var camera: Camera3D

@export var friction_coefficient: float = 0.2
@export var drag_coefficient: float = 0.05
@export var shield_durability: float = 100.0

@onready var direction
@onready var target_points = []
@onready var speed_mult = 1.0
@onready var air_mult = 1.0
@onready var downward_raycast = $"Downward RayCast"
@onready var ray_to_cam = $"To Cam RayCast"
@onready var jump_num = 0
@onready var wall_jump = 0
@onready var aiming = false
@onready var crouching = false
@onready var slide = false
@onready var horiz_cam_mult = 1
@onready var gun = $"Body Mesh Container/gun"

var input_dir
var horizontal
var vertical
var target
var to_target
var last_target
var state = FLOOR
var camera_T = float()
var tform_point = Vector3()
var slide_speed = 5.0  # Speed of sliding
var manual_move_cam

var floor_angle = get_floor_angle()
var floor_normal = get_floor_normal()
var floor_velocity = Vector3.ZERO
var timer_started
var last_jump_timed
var last_jump_far


func _ready() -> void:
	camera_target = camera_parent.camera_target
	camera = camera_parent.camera
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	

func _physics_process(delta: float) -> void:
	
	floor_angle = get_floor_angle()
	floor_normal = get_floor_normal()
	
	$RichTextLabel2.text = str(velocity.length())
	if Input.is_action_just_pressed("ESC"):
		get_tree().quit()
	
	if not is_on_floor() and state != ON_TARGET:
		if is_on_wall_only():
			state = WALL
		else:
			state = AIR
	elif state != ON_TARGET:
		state = FLOOR

	if Input.is_action_pressed("E"):
		aiming = true
	else:
		aiming = false
		
	$RichTextLabel3.text = str(" Ammo: ", $"Body Mesh Container/gun".ammo)
	if Input.is_action_just_pressed("shift"):
		if state != AIR and state != ON_TARGET:
			crouching = !crouching
		if state == ON_TARGET:
			target.queue_free()
			$"Body Mesh Container/gun".ammo += 1
			target = null
			jump()
			state = AIR
		elif state == AIR:
			air_stop()

	#paraglider (too slow)
	if Input.is_action_pressed("ui_accept") and state == AIR:
		if state == AIR and velocity.y < -4.125:
			velocity.y += 0.2
			manual_move_cam = true
	else:
		if not jump_num == 2: manual_move_cam = false

	if Input.is_action_just_pressed("Q"):
		horiz_cam_mult = horiz_cam_mult * -1
		
	

	if Input.is_action_just_pressed("ui_accept"):
		if $"Jump Timed".time_left > 0.85:
			jump_timed()
		else:
			jump()
		target = null

	if target != null:
		var distance_to_player = (target.global_transform.origin - global_transform.origin).length()
		if distance_to_player == 0:
			state = ON_TARGET

	if state == FLOOR:
		wall_jump = 0
		if timer_started == false:
			$"Jump Timed".start(1.0)
			timer_started = true
		$RichTextLabel.text = str("FLOOR")
		$"Body Mesh Container/MeshInstance3D2".visible = true
		$"Body Mesh Container/MeshInstance3D".visible = true

	if state == AIR:
		if target != null and velocity.y < 0:
			to_target = true
		crouching = false
		timer_started = false
		$"Jump Timed".stop()
		air_mult = lerp(air_mult, 0.5, 0.0125)
		if speed_mult >= 1.0 and velocity.y > 1 and not Input.is_action_pressed("ui_accept"):
			speed_mult = lerp(speed_mult, (velocity.y), 0.005)
		if speed_mult < 1.0:
			speed_mult = lerp(speed_mult, 1.0, 0.08)
		$RichTextLabel.text = str("AIR")
		velocity += get_gravity() * delta
	else:
		if not crouching:
			speed_mult = lerp(speed_mult, 1.0, 0.08)
		air_mult = 1.0

	if state == WALL:
		crouching = false
		$RichTextLabel.text = str("WALL")
		velocity += get_gravity() * delta

	if state == TO_TARGET:
		crouching = false
		$RichTextLabel.text = str("TO TARGET")
		if target == null or velocity.y > 0:
			state = AIR
	elif state == ON_TARGET and target != null:
		$CollisionShape3D.disabled = false
		crouching = false
		$RichTextLabel.text = str("ON TARGET", " : ", target)
		global_transform.origin = target.global_transform.origin
		
		if target == null:
			state = AIR
	else:
		target = null

	camera_T = camera_target.global_transform.basis.get_euler().y
	var joystick_input = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if joystick_input.length() > 0:
		joystick_input = joystick_input.normalized()
	horizontal = joystick_input.x
	vertical = joystick_input.y
	var left_stick_pressure = Input.get_action_strength("ui_left") + Input.get_action_strength("ui_right") + Input.get_action_strength("ui_up") + Input.get_action_strength("ui_down")
	left_stick_pressure = clamp(left_stick_pressure, 0, 1)
	direction = (transform.basis * Vector3(horizontal * air_mult * speed_mult, 0.0, vertical * air_mult * speed_mult * left_stick_pressure).rotated(Vector3.UP, camera_T)).normalized()
	if direction:
		var speed_factor = velocity.length() / SPEED / 2
		var lerp_speed = clamp(0.2 * (1 - speed_factor), 0.01, 0.1) * air_mult
		var target_velocity = direction * SPEED * speed_mult
		velocity.x = lerp(velocity.x, target_velocity.x * left_stick_pressure, lerp_speed)
		velocity.z = lerp(velocity.z, target_velocity.z * left_stick_pressure, lerp_speed)
	elif state != AIR and slide:
		velocity.x = lerp(velocity.x, 0.0, 0.001)
		velocity.z = lerp(velocity.z, 0.0, 0.001)
	elif state != AIR:
		velocity.x = lerp(velocity.x, 0.0, 0.5)
		velocity.z = lerp(velocity.z, 0.0, 0.5)
		

	if get_floor_normal().dot(Vector3.UP) < cos(MAX_SLOPE_ANGLE):
		apply_slope_slide(floor_normal, delta)
	#else:
		#cam_zoom_reset()

	# Calculate the desired rotation angle
	var target_rotation_y = $"Look_At Rotation".rotation.y
	var current_rotation_y = $"Body Mesh Container".rotation.y

# Calculate the difference between current and target rotation
	var angle_difference = wrapf(target_rotation_y - current_rotation_y, -PI, PI)

	var look_val
	if not aiming:
		look_val = 0.075 * left_stick_pressure
	else: look_val = 1

# Apply rotation with clamped smoothing
	$"Body Mesh Container".rotation.y += angle_difference * look_val * speed_mult * air_mult

	if aiming:
		## manually move y axis of camera
		#look_val = 0.3
		$"Look_At Rotation".rotation.y = camera_target.rotation.y
	else:
		#look_val = 0.1
		$"Look_At Rotation".look_at(position + direction)
	if crouching:
		speed_mult = 0.65
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.7, 0.2)
		$"Body Mesh Container/Capsule".mesh.height = lerp($"Body Mesh Container/Capsule".mesh.height, 1.7, 0.2)
	else:
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 2.0, 0.2)
		$"Body Mesh Container/Capsule".mesh.height = lerp($"Body Mesh Container/Capsule".mesh.height, 2.0, 0.2)
	
	if not aiming:
		if velocity.length() > 1: $"Body Mesh Container".rotation.y += angle_difference * look_val * air_mult * speed_mult
		else: $"Body Mesh Container".rotation.y += angle_difference * look_val * air_mult * speed_mult * velocity.length()
	#if velocity.length() > 1: $"Body Mesh Container".rotation.y = lerpf($"Body Mesh Container".rotation.y, $"Look_At Rotation".rotation.y , 0.1)
	#else: $"Body Mesh Container".rotation.y = lerpf($"Body Mesh Container".rotation.y, $"Look_At Rotation".rotation.y , 0.1 * velocity.length())
	
	var direction_2d = Vector2(direction.x, direction.z)
	target_rotation_y = direction_2d.angle()

	if horizontal == -1 and not aiming and not state == AIR:
		camera_parent.yaw += velocity.length() / (5.5-vertical) * delta * left_stick_pressure
	if horizontal == 1 and not aiming and not state == AIR:
		camera_parent.yaw -= velocity.length() / (5.5-vertical) * delta * left_stick_pressure

	camera_smooth_follow(delta)
	sort_target_points(delta)
	if state == AIR or state == TO_TARGET or state == ON_TARGET:
		apply_magnetism(delta)
	#find_floor_velocity(delta)
	move_and_slide()

func jump():
	if crouching and velocity.length() < 3.5:
		jump_num = 1
		if direction:
			velocity.y += JUMP_VELOCITY + (2.21 / 2.4)
		else:
			velocity.y += JUMP_VELOCITY + (2.21 / 1.125)
		manual_move_cam = false
		speed_mult = 25.0
		last_jump_far = true
	elif state == ON_TARGET:
		state = AIR
		velocity.y += JUMP_VELOCITY + (2.21 / 1.25)
		jump_num = 1
		last_jump_far = false
	elif is_on_floor() and not get_floor_normal().dot(Vector3.UP) < cos(MAX_SLOPE_ANGLE):
		manual_move_cam = false
		velocity.y += JUMP_VELOCITY
		jump_num = 1
		last_jump_far = false
	elif is_on_floor() and get_floor_normal().dot(Vector3.UP) < cos(MAX_SLOPE_ANGLE):
		manual_move_cam = true
		last_jump_far = false
		if direction and $"Body Mesh Container/Ledge Check Ray".is_colliding():
			if get_floor_normal().dot(Vector3.UP) < cos(40):
				velocity.y += JUMP_VELOCITY / 1.5
				velocity += floor_normal * JUMP_VELOCITY * 1.5
			else:
				velocity.y += JUMP_VELOCITY
				velocity += floor_normal * JUMP_VELOCITY / 2
		else:
			velocity.y += JUMP_VELOCITY
		jump_num = 1
		last_jump_timed = false
	else:
		if jump_num < 2:
			jump_num += 1
			air_mult = 1.0
			speed_mult = 1.0
			if velocity.y > 2.5:  # Rising phase of the first jump
				#manual_move_cam = true
				velocity.y += (2.21 / velocity.y * 2.21)/1.25 # Smaller boost if rising
				last_jump_timed = true
			elif velocity.y < 2.21 and velocity.y > 0:
				velocity.y += (2.21 + velocity.y/2.21)/1.25
				last_jump_timed = true
			else:  # Falling phase of the jump
				velocity.y += 2.21 - velocity.y
				last_jump_timed = true
		#if jump_num < 3:
			#if state == WALL and wall_jump < 2:
				#velocity = get_wall_normal() * (JUMP_VELOCITY + 2.21)
				#speed_mult = 0.0
				#velocity.y += JUMP_VELOCITY
				#jump_num = 1
				#wall_jump += 1
	
func jump_timed():
	jump_num = 1
	manual_move_cam = false
	var jumpmult
	if last_jump_far == true or last_jump_timed == true:
		jumpmult = 1.25
	else:
		jumpmult = 2.4
	velocity.y += JUMP_VELOCITY + (2.21 / jumpmult)
	last_jump_timed = true
	last_jump_far = false

func air_stop():
	if jump_num < 3:
		jump_num += 1
		velocity = Vector3.ZERO
		#velocity.y += 2.21
		last_jump_far = true

func apply_slope_slide(normal: Vector3, delta: float) -> void:
	if is_on_floor():
		manual_move_cam = true
		
		var slide_direction = (normal - Vector3.UP)
		var floor_normal = get_floor_normal()
		var slope_angle = acos(floor_normal.dot(Vector3.UP))
		
		var adjusted_velocity = velocity.slide(floor_normal)
		velocity.x = lerp(velocity.x, velocity.x + slide_direction.x * 3.25, delta * 5)
		velocity.z = lerp(velocity.z, velocity.z + slide_direction.z * 3.25, delta * 5)
		if velocity.y > 0:
			velocity.y = lerp(velocity.y, velocity.y - adjusted_velocity.y / 1.25, delta * 5)
			#if velocity.length() < 4.0 and not aiming:
				#cam_zoom_in()
			#else:
				#cam_zoom_reset()
		else:
			velocity.y = lerp(velocity.y, velocity.y + adjusted_velocity.y, delta * 5)
			#if velocity.length() > 4.5 and not aiming:
				#cam_zoom_out()
			#else:
				#cam_zoom_reset()
		

func find_floor_velocity(delta):
	if downward_raycast.is_colliding():
		var floorcol = downward_raycast.get_collider()
		if floorcol.is_in_group("moving platform"):
			floor_velocity = floorcol.velocity
			#velocity = floor_velocity

func move_with_platform(platform_velocity: Vector3):
	# Apply the platform velocity to the player's movement
	# For example, you can apply the velocity directly to the player's position
	# or add it to the player's velocity

	# Adjust the player's position based on the platform's velocity
	# You might want to apply this to the player's 'global_transform.origin'
	global_transform.origin += platform_velocity * get_process_delta_time()

func sort_target_points(delta):
	var closest_point = null
	var min_distance = INF
	var predicted_position = global_transform.origin + velocity * delta
	var best_target = null
	var max_distance_reduction = -INF
	for potential_target in target_points:
		var current_distance = global_transform.origin.distance_to(potential_target.global_transform.origin)
		var predicted_distance = predicted_position.distance_to(potential_target.global_transform.origin)
		var distance_reduction = current_distance - predicted_distance
		if current_distance < min_distance:
			min_distance = current_distance
			closest_point = potential_target
			best_target = closest_point
		else:
			best_target = null
		if best_target != null:
			target = best_target

func apply_magnetism(delta): # the holy grail of magnetism
	if target != null and velocity.y < 0:  # No magnetism if jumping
		var distance_to_player = global_transform.origin.distance_to(target.global_transform.origin)
		state = TO_TARGET
		if distance_to_player < 4 and global_transform.origin.y >= target.global_transform.origin.y - 0.25: # natural move toward
			var magnet_direction = (target.global_transform.origin - global_transform.origin).normalized()
			velocity = lerp(velocity, magnet_direction * SPEED * 2.25, 0.1 / (distance_to_player + 0.1))
			#velocity = lerp(velocity, magnet_direction * SPEED * 2.25 + Vector3(0,0.0 * SPEED * 2.25,0), 0.1 / (distance_to_player + 0.1))
		if distance_to_player < 1 and global_transform.origin.y <= target.global_transform.origin.y + 0.15:
			velocity = Vector3.ZERO # perfect snapping
			$CollisionShape3D.disabled = true
			global_transform.origin.y = lerp(global_transform.origin.y, target.global_transform.origin.y, 0.125 / (distance_to_player + 0.125))
			global_transform.origin.x = lerp(global_transform.origin.x, target.global_transform.origin.x, 0.125 / (distance_to_player + 0.125))
			global_transform.origin.z = lerp(global_transform.origin.z, target.global_transform.origin.z, 0.125 / (distance_to_player + 0.125))
		else:
			$CollisionShape3D.disabled = false
	else:
		$CollisionShape3D.disabled = false

func cam_zoom_in():
	camera.fov = lerp(camera.fov, 50.0, 0.02)
func cam_zoom_out():
	camera.fov = lerp(camera.fov, 75.0, 0.02)
func cam_zoom_reset():
	camera.fov = lerp(camera.fov, 65.0, 0.2)

func camera_smooth_follow(delta):
	var cam_speed = 350
	var cam_timer = clamp(delta * cam_speed / 20, 0, 1)
	var cam_to_player_x = abs(camera_parent.camera.global_transform.origin.x - global_transform.origin.x)
	var cam_to_player_y = abs(camera_parent.camera.global_transform.origin.y - global_transform.origin.y)
	var cam_to_player_z = abs(camera_parent.camera.global_transform.origin.z - global_transform.origin.z)
	var cam_distance = (cam_to_player_x + cam_to_player_y + cam_to_player_z) / 3
	var tform_mult
	var offsetform = global_transform.origin + global_transform.basis.z * 1

	var camera_length = -camera_parent.pitch * 4
	var cam_max
	var cam_min
	var lerp_val
	if not aiming:
		cam_zoom_reset()
		lerp_val = 0.125/3 * velocity.length()
		var add
		if crouching: add = 5
		else: add = 5.5
		cam_max = 1
		cam_min = -3
		tform_mult = 1.25
		camera_length = clamp(camera_length, cam_min, cam_max)
		camera.position = lerp(camera.position, Vector3(horiz_cam_mult * 0,0.75, camera_length + add), 0.175)
		$"Body Mesh Container/gun".position = lerp($"Body Mesh Container/gun".position, Vector3(0, 0.125, -0.75), 0.175)
	else:
		cam_zoom_in()
		lerp_val = 1
		cam_max = 0.5
		cam_min = -0.5
		tform_mult = 0
		camera_length = clamp(camera_length, cam_min, cam_max)
		camera.position = lerp(camera.position, Vector3(horiz_cam_mult * 1.5 ,0 ,camera_length + 2.5), 0.175)
		$"Body Mesh Container/gun".position = lerp($"Body Mesh Container/gun".position, Vector3(horiz_cam_mult * 0.75, 0.125, -0.75), 0.175)
		camera.fov = lerp(camera.fov, 55.0, 0.2)
	
	var tform = $"Body Mesh Container/Capsule".global_transform.origin - $"Body Mesh Container".global_transform.basis.z * tform_mult
	$Basis_Offset.global_transform.origin.x = lerp($Basis_Offset.global_transform.origin.x, tform.x, cam_timer / 2 * lerp_val)
	$Basis_Offset.global_transform.origin.z = lerp($Basis_Offset.global_transform.origin.z, tform.z, cam_timer / 2 * lerp_val)
	camera_parent.position.x = lerp(camera_parent.position.x, $Basis_Offset.global_transform.origin.x, 1)
	camera_parent.position.z = lerp(camera_parent.position.z, $Basis_Offset.global_transform.origin.z, 1)
	if state == AIR:
		if manual_move_cam == true:
			camera_parent.position.y = lerp(camera_parent.position.y, global_transform.origin.y + 1.75, 0.055)
		elif not $"CollisionShape3D/Cam Y Ray".is_colliding():
			camera_parent.position.y = lerp(camera_parent.position.y, global_transform.origin.y + 1.75, 0.055)
		else:
			if velocity.y <= -4 and global_transform.origin.y < camera_parent.global_transform.origin.y - 2: # and not downward_raycast.is_colliding()
				camera_parent.position.y = lerp(camera_parent.position.y, global_transform.origin.y + 1.75, 0.1)
				if not aiming:
					camera_parent.pitch = lerp(camera_parent.pitch, deg_to_rad(camera_parent.pitch_min + 30), 0.02)
	else:
		camera_parent.position.y = lerp(camera_parent.position.y, global_transform.origin.y + 1.75, 0.055)

	var ray_to_cam_distance =  ray_to_cam.global_transform.origin - camera.global_transform.origin
	ray_to_cam.look_at(camera.global_position)
	ray_to_cam.target_position = Vector3(0,0,-ray_to_cam_distance.length())

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("target"):
		print("body added")
		target_points.append(body)

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("target"):
		print("body removed")
		target_points.erase(body)
