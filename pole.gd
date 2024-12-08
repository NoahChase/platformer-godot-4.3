extends Node3D

@export var player: CharacterBody3D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"Path3D/PathFollow3D/Mid Rot/Magnet Point".player = player

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
