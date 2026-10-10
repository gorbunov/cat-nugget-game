extends RefCounted
## Mutable flight and bite state. One record is shared by simulation and rendering.

var kind: String
var variant: int
var hp: int
var bite_wait := 0.0
var pos: Vector2
var vel: Vector2
var gravity: float
var age := 0.0
var rotation: float
var spin: float


func _init(nugget_kind: String, hit_points: int, position: Vector2,
		velocity: Vector2, acceleration: float, sprite_variant: int,
		initial_rotation: float, angular_velocity: float) -> void:
	kind = nugget_kind
	hp = hit_points
	pos = position
	vel = velocity
	gravity = acceleration
	variant = sprite_variant
	rotation = initial_rotation
	spin = angular_velocity
