extends Node3D

@export var player := CharacterBody3D
@export var camera_parent: Node3D

@onready var anim = $AnimationPlayer
@onready var bullet_scene : PackedScene = load("res://magnet_point.tscn")

@onready var ammo = 1

var aimed_at_target
var target
var previous_target
var shoot = true
var bullet_chambered = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _ready():
	camera_parent = player.camera_parent

func _process(delta):
	var aim_target = $muzzle/RayCast3D/AimPositioner/AimTarget
	if $muzzle/RayCast3D.is_colliding():
		target = $muzzle/RayCast3D.get_collider()
		if not target.is_in_group("player"):
			$muzzle/RayCast3D/AimPositioner/AimTarget.global_transform.origin = $muzzle/RayCast3D.get_collision_point()
			if target.is_in_group("target"):
				aimed_at_target = true
				previous_target = target
				target.scale.x = 1.5
				target.scale.y = 1.5
				target.scale.z = 1.5
				$muzzle/RayCast3D/AimPositioner/AimTarget/MeshInstance3D.material_override.albedo_color = Color(1,0,0)
			elif previous_target != null:
				previous_target.scale.x = 1
				previous_target.scale.y = 1
				previous_target.scale.z = 1
				$muzzle/RayCast3D/AimPositioner/AimTarget/MeshInstance3D.material_override.albedo_color = Color(0,1,0)
		else:
			if previous_target != null:
				previous_target.scale.x = 1
				previous_target.scale.y = 1
				previous_target.scale.z = 1
				$muzzle/RayCast3D/AimPositioner/AimTarget/MeshInstance3D.material_override.albedo_color = Color(0,1,0)
			aimed_at_target = false
	else:
		if target != null and target.is_in_group("target"):
			target.scale.x = 1
			target.scale.y = 1
			target.scale.z = 1
			$muzzle/RayCast3D/AimPositioner/AimTarget/MeshInstance3D.material_override.albedo_color = Color(0,1,0)
		target = null
		if previous_target != null:
			previous_target.scale.x = 1
			previous_target.scale.y = 1
			previous_target.scale.z = 1
			$muzzle/RayCast3D/AimPositioner/AimTarget/MeshInstance3D.material_override.albedo_color = Color(0,1,0)
		else:
			$muzzle/RayCast3D/AimPositioner/AimTarget/MeshInstance3D.material_override.albedo_color = Color(0,1,0)
		$muzzle/RayCast3D/AimPositioner/AimTarget.position = Vector3(0,0,0)
	
	look_at(player.camera_parent.aim_target.global_transform.origin, Vector3.UP)
	rotation.y = clamp(rotation.y, deg_to_rad(-130), deg_to_rad(130))
	if shoot:
		if aimed_at_target and target != null and target.is_in_group("target") and Input.is_action_just_pressed("LMB"):
			target.queue_free()
			ammo += 1
		elif not anim.current_animation == "shoot" and Input.is_action_just_pressed("LMB"):
			if ammo > 0:
				anim.queue("shoot")
				decide_shoot()
				anim.queue("reset")
		
		if anim.current_animation == "reset" or anim.current_animation == "no reset":
			bullet_chambered = true
		
		if anim.current_animation == "shoot":
			bullet_chambered = false

func decide_shoot():
	ammo -= 1
	#$"Gun Audio".pitch_scale = randf_range(0.75, 1)
	#$"Gun Audio".play()
	var bullet = bullet_scene.instantiate()
	self.add_child(bullet)
	if player.camera_parent.aim_raycast.is_colliding():
		bullet.global_transform = $muzzle.global_transform
		bullet.shoot_from_gun = true
	else:
		bullet.global_transform = $muzzle.global_transform
		bullet.shoot_from_gun = true
			
	bullet.shootable = true
	bullet.player = player
	anim.play("reset")
