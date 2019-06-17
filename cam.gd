extends Camera

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("ui_up"):
		translation -= transform.basis.z * 5.0 * delta
	if Input.is_action_pressed("ui_down"):
		translation += transform.basis.z * 5.0 * delta
	if Input.is_action_pressed("ui_left"):
		get_parent().rotate_y(-delta)
	if Input.is_action_pressed("ui_right"):
		get_parent().rotate_y(delta)
