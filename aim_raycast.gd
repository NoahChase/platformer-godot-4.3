extends RayCast3D

@export var camera_parent = Node3D

@onready var aim_positioner = $AimPositioner
@onready var aim_target = $AimPositioner/AimTarget
@onready var aim_rememberer = $AimRememberer
@onready var cam_moving = false
@onready var previous_aim_position = Vector3.ZERO

var aiming_with_backup

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	var distance
	var is_any_colliding = false
	
	if is_colliding():
		aiming_with_backup = false
		is_any_colliding = true
		var target = get_collider()
		if not target == null and not target.is_in_group("player"):
			aim_target.global_transform.origin = get_collision_point()
			aim_rememberer.global_transform.origin = get_collision_point()
			previous_aim_position = aim_target.position
	elif not cam_moving:
		if aiming_with_backup:
			var ray_offset = global_transform.origin - camera_parent.backup_ray.global_transform.origin
			aim_rememberer.global_transform.origin = camera_parent.backup_ray.get_collision_point() + ray_offset
			previous_aim_position = aim_rememberer.global_transform.origin
			aim_target.position = previous_aim_position
		else:
			aim_target.position = lerp(aim_target.position, Vector3(0,0,0), 0.01)
	else:
		if aiming_with_backup == false:
			aim_target.position = lerp(aim_target.position, previous_aim_position, 0.01)
		else:
			pass
	if not is_colliding():
		for ray in camera_parent.backuprays:
			if ray.is_colliding():
				is_any_colliding = true
				var target = ray.get_collider()
				if not target.is_in_group("player"):
					aiming_with_backup = true
					var ray_offset = global_transform.origin - ray.global_transform.origin
					aim_rememberer.global_transform.origin = ray.get_collision_point() + ray_offset
					previous_aim_position = aim_rememberer.global_transform.origin
					aim_target.global_transform.origin = previous_aim_position
			
			
		
		
	
	#elif
		#for ray in backup_rays:
			#if ray.is_colliding():
				#var target = ray.get_collider()
				#if not target.is_in_group("player"):
					#is_any_colliding = true
					#distance = (ray.global_transform.origin - ray.get_collision_point()).length()
#
					## Move aim_target along the local Z-axis of the parent raycast
					#aim_target.global_transform.origin = self.global_transform.origin + self.global_transform.basis.z * -distance
					#break
	#if not is_any_colliding:
		#
