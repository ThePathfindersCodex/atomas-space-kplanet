extends Node2D
class_name Star

var g; # game object
var max_distance_allowed = 20000	

func _ready():
	g = get_parent()
