extends Node3D

# Laser properties
@export var max_length: float = 4000  # Maximum laser range
@export var laser_thickness: float = 0.3  # Cylinder radius for the laser

# Nodes
@onready var laser = $Laser  # The CylinderMesh
@onready var raycast = $RayCast3D  # The raycast

func _ready():
	# Set initial laser size and thickness
	laser.scale = Vector3(laser_thickness, 1, 1)  # X = Radius, Z = Length, Y = Unused
	laser.visible = false  # Hide until the laser is active


func _physics_process(delta):
	# Update raycast
	raycast.force_raycast_update()

	# Check for collision
	var hit_position: Vector3
	if raycast.is_colliding():
		hit_position = raycast.get_collision_point()
	else:
		# Default to max length if no collision
		hit_position = raycast.global_transform.origin + raycast.global_transform.basis.z * max_length

	# Calculate the laser length
	var laser_length = (hit_position - raycast.global_transform.origin).length()

	# Update the laser scale
	laser.scale = Vector3(laser_thickness, 1, laser_length / 2)  # Scale in Z is half since the cylinder extends from the center

	# Offset the laser's position to align it with the muzzle
	var offset = Vector3(0, 0, laser_length / 2)  # Laser starts at the muzzle
	laser.transform.origin = laser.transform.origin + laser.global_transform.basis.z * offset.z

	# Show the laser
	laser.visible = true
