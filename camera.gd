extends Node3D

@onready var camera_return = $CameraTarget/Camera_Return
@onready var aim_target = $"CameraTarget/Camera3D/Aim Raycast/AimPositioner/AimTarget"
@onready var aim_raycast = $"CameraTarget/Camera3D/Aim Raycast"
@onready var backup_ray = $CameraTarget/Camera3D/RayCast3D
@onready var backuprays = [$CameraTarget/Camera3D/RayCast3D, $CameraTarget/Camera3D/RayCast3D2, $CameraTarget/Camera3D/RayCast3D3, $CameraTarget/Camera3D/RayCast3D4]

@export var camera_target = Node3D
@export var camera_player = CharacterBody3D
@export var camera = Camera3D
@export var shoot_start_point = Node3D
@export var pitch_max = 42
@export var pitch_min = -80
@export var aim_pitch_max = 80
@export var aim_pitch_min = -80

var right_stick_pressure
var left_stick_pressure
@onready var handling_obstruction = false
var distance = Vector3()
@onready var avg_distance = 1
@onready var mouse_motion

var yaw = float()
var pitch = float()
var yaw_sens = 0.001
var pitch_sens = 0.001

var default_camera_offset := Vector3(0, 0, -4.5)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() !=0:
		mouse_motion = true
		yaw += -event.relative.x * (yaw_sens/360) * avg_distance
		pitch += -event.relative.y * (pitch_sens/360) * avg_distance
	else:
		mouse_motion = false

func _physics_process(delta):
	var cam_input_x = Input.get_axis("right_stick_right", "right_stick_left")
	var cam_input_y = Input.get_axis("right_stick_down", "right_stick_up")
	var stick_vector = Vector2(cam_input_x, cam_input_y)

# Dead zone
	var dead_zone = 0.1
	var stick_magnitude = stick_vector.length()
	if stick_magnitude > dead_zone:
		stick_vector = stick_vector.normalized() * ((stick_magnitude - dead_zone) / (1.0 - dead_zone))
	else:
		stick_vector = Vector2.ZERO

# Adjust yaw and pitch with dynamic scaling
	yaw += stick_vector.x * yaw_sens * delta
	pitch += stick_vector.y * pitch_sens * delta

# Apply smooth interpolation to the camera
	camera_target.rotation.y = lerp(camera_target.rotation.y, yaw, delta * 15)
	camera_target.rotation.x = lerp(camera_target.rotation.x, pitch, delta * 15)

	if camera_player.aiming:
		pitch = clamp(pitch, deg_to_rad(aim_pitch_min), deg_to_rad(aim_pitch_max))
		yaw_sens = 1.5
		pitch_sens = 1.5
	else:
		pitch = clamp(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
		yaw_sens = 1.5
		pitch_sens = 1.5

	if camera_player.ray_to_cam.is_colliding():
		var wall_detect = camera_player.ray_to_cam.get_collider()
		var wall_distance = wall_detect.position - camera.global_position
		if not wall_detect.is_in_group("player"):
			camera.global_transform.origin = lerp(camera.global_transform.origin, camera_player.ray_to_cam.get_collision_point(), 0.9)

	if camera_player.aiming:
		$CameraTarget/Camera3D/TextureRect.visible = true
	else:
		$CameraTarget/Camera3D/TextureRect.visible = false

	var screen_position = $CameraTarget/Camera3D.unproject_position($"CameraTarget/Camera3D/Aim Raycast/AimRememberer".global_transform.origin)
	var viewport = $CameraTarget/Camera3D.get_viewport().get_visible_rect().size
	
	# Define a scale factor (e.g., 0.9 for 90%)
	var scale_factor = .8

	# Create a scaled-down viewport rect
	var smaller_viewport = viewport * scale_factor

	print("Full Viewport Size:", viewport)
	print("Smaller Viewport Size:", smaller_viewport)
	
	# Check if the screen position is outside the viewport boundaries
	if screen_position.x < 0 or screen_position.y < 0 or screen_position.x > smaller_viewport.x or screen_position.y > smaller_viewport.y:
		aim_raycast.cam_moving = false
		aim_raycast.aiming_with_backup = false
	elif not aim_raycast.is_colliding():
		for ray in backuprays:
			if ray.is_colliding():
				var target = ray.get_collider()
				if not target == null and target.is_in_group("player"):
					aim_raycast.cam_moving = true
	else:
		aim_raycast.cam_moving = true

func return_camera_to_position(delta):
	camera.global_position = camera.global_position.lerp(camera_return.global_transform.origin, 0.015)

func rotate_yaw(delta):
	yaw += 1
