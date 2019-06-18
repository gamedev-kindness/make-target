extends Control

func generate_run():
	get_tree().change_scene("res://generate_maps.tscn")
func run():
	get_tree().change_scene("res://map_test.tscn")
func _ready():
	$VBoxContainer/generate_run.connect("pressed", self, "generate_run")
	$VBoxContainer/run.connect("pressed", self, "run")
