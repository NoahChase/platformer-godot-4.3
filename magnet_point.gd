extends StaticBody3D

@export var player := CharacterBody3D
@export var shootable: bool = false
@export var shoot_from_gun: bool = false
@export var mesh := MeshInstance3D

var previous_position : Vector3 = Vector3.ZERO
var velocity : Vector3 = Vector3.ZERO

var dis_2_player

# Called every frame. 'delta' is the elapsed time since the previous frame.
var target = null  # Initialize the target variable
var relative_position = Vector3.ZERO  # Initialize relative position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	
	if shootable:
		# Move the magnet point if not colliding with anything
		if not $"Projectile Raycast".is_colliding() and not $"Projectile Raycast2".is_colliding() and not $"Projectile Raycast3".is_colliding():
			if shoot_from_gun:
				position += transform.basis.z * 50 * delta
			else:
				position -= transform.basis.z * 50 * delta
			
			if $"Shootable Timer".is_stopped():
				$"Shootable Timer".start(10)
			if $"Shootable Timer".time_left < 0.1:
				player.gun.ammo += 1
				queue_free()
			
		else:
			# Find the target if any of the raycasts are colliding
			var collision_point = Vector3.ZERO
			if $"Projectile Raycast".is_colliding():
				collision_point = $"Projectile Raycast".get_collision_point()
				target = $"Projectile Raycast".get_collider()
			elif $"Projectile Raycast2".is_colliding():
				collision_point = $"Projectile Raycast2".get_collision_point()
				target = $"Projectile Raycast2".get_collider()
			elif $"Projectile Raycast3".is_colliding():
				collision_point = $"Projectile Raycast3".get_collision_point()
				target = $"Projectile Raycast3".get_collider()
				
			if target != null:
				if target.is_in_group("player"):
					target = null
				elif target.is_in_group("moving platform"):
					
					# Convert the collision point from world space to the target's local space
					var local_collision_point = target.to_local(collision_point)
					
					# Spawn RemoteTransform3D at the correct relative position
					var remote_transform = RemoteTransform3D.new()
					remote_transform.remote_path = self.get_path()
					
					# Add the RemoteTransform3D to the target
					target.add_child(remote_transform)

					# Correctly set the relative position
					#relative_position = collision_point - target.global_transform.origin
					#remote_transform.global_transform.origin = collision_point + local_collision_point

					relative_position = global_transform.origin - target.global_transform.origin
					remote_transform.global_transform.origin = global_transform.origin

					# Stop the projectile movement after the initial collision
					self.add_to_group("moving platform")
					remote_transform.add_to_group("moving platform")
					target.add_to_group("moving platform")
					shootable = false

					
				else:
					# For static platforms, calculate relative position normally
					relative_position = global_transform.origin - target.global_transform.origin
					shootable = false
	else:
		# If the target exists, move the magnet point to stick with the platform
		if target != null and not target.is_in_group("moving platform"):
			# Update the magnet point's global position relative to the platform
			global_transform.origin = target.global_transform.origin + relative_position

	# Handle snapping to player
	dis_2_player = global_transform.origin - player.global_transform.origin
	if dis_2_player.length() <= 0.15:  # Slightly increase threshold for reliability
		if player.state == player.TO_TARGET or player.state == player.ON_TARGET:
			player.velocity = Vector3.ZERO  # Stop any movement before snapping
			player.state = player.ON_TARGET
