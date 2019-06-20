extends Camera

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

var drag: bool = false
var motion : = Vector2()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if motion.length() > 1.0:
		translation -= transform.basis.z * 1.5 * motion.y * delta
		get_parent().rotate_y(motion.x * 0.9 * delta)
		motion = Vector2()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 && event.is_pressed():
			drag = true
		elif event.button_index == 1 && !event.is_pressed():
			drag = false
	elif event is InputEventMouseMotion:
		if drag:
			motion += event.relative
