extends StaticBody3D

var previous_position : Vector3 = Vector3.ZERO
var velocity : Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		# Calculate the velocity by comparing the current position with the previous one
	velocity = (global_transform.origin - previous_position) / delta
	# Update the previous position for the next frame
	previous_position = global_transform.origin
