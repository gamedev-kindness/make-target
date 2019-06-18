extends Spatial

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
onready var characters = [load("res://characters/female_2018.escn"), load("res://characters/male_2018.escn")]
var body_mi: MeshInstance
var body_mesh: ArrayMesh
var orig_body_mesh: ArrayMesh
const TEX_SIZE = 512
var min_point: Vector3 = Vector3()
var max_point: Vector3 = Vector3()
var min_normal: Vector3 = Vector3()
var max_normal: Vector3 = Vector3()
var maps = {}
var vert_indices = {}
func find_same_verts():
	for surface in range(orig_body_mesh.get_surface_count()):
		var arrays: Array = orig_body_mesh.surface_get_arrays(surface).duplicate(true)
		for index1 in range(arrays[ArrayMesh.ARRAY_VERTEX].size()):
			var v1: Vector3 = arrays[ArrayMesh.ARRAY_VERTEX][index1]
			var ok = false
			for rk in vert_indices.keys():
				if (v1 - rk).length() < 0.001:
					ok = true
					vert_indices[rk].push_back(index1)
			if !ok:
				vert_indices[v1] = [index1]

func find_mesh(base: Node, mesh_name: String) -> MeshInstance:
	var queue = [base]
	var mi: MeshInstance
	while queue.size() > 0:
		var item = queue[0]
		queue.pop_front()
		if item is MeshInstance && item.name == mesh_name:
			mi = item
			break
		for c in item.get_children():
			queue.push_back(c)
	return mi
func update_modifier(value: float, modifier: String, slider: HSlider):
	body_mi.hide()
	body_mi.mesh = null
	var val = value / 100.0
	val = clamp(val, 0.0, 1.0)
	for k in maps.keys():
		maps[k].image.lock()
		maps[k].image_normal.lock()
	maps[modifier].value = val
	var surf : = 0
	print(modifier, " ", val)
	body_mesh = ArrayMesh.new()
	for surface in range(orig_body_mesh.get_surface_count()):
		var arrays: Array = orig_body_mesh.surface_get_arrays(surface).duplicate(true)
		for index in range(arrays[ArrayMesh.ARRAY_VERTEX].size()):
			var v: Vector3 = arrays[ArrayMesh.ARRAY_VERTEX][index]
			var n: Vector3 = arrays[ArrayMesh.ARRAY_NORMAL][index]
			var uv: Vector2 = arrays[ArrayMesh.ARRAY_TEX_UV][index]
			var pos: Vector2 = uv * TEX_SIZE
			var diff : = Vector3()
			var diffn : = Vector3()
			for k in maps.keys():
				var offset: Color = maps[k].image.get_pixelv(pos)
				var offsetn: Color = maps[k].image_normal.get_pixelv(pos)
				var pdiff: Vector3 = Vector3(offset.r, offset.g, offset.b)
				var ndiff: Vector3 = Vector3(offsetn.r, offsetn.g, offsetn.b)
				for u in range(2):
					diff[u] = (pdiff[u] * (max_point[u] - min_point[u]) + min_point[u]) * maps[k].value
					diffn[u] = (ndiff[u] * (max_normal[u] - min_normal[u]) + min_normal[u]) * maps[k].value
					if abs(diff[u]) < 0.0001:
						diff[u] = 0
				v -= diff
				n -= diffn
#			print(pdiff, " ", diff)
			arrays[ArrayMesh.ARRAY_VERTEX][index] = v
			arrays[ArrayMesh.ARRAY_NORMAL][index] = n.normalized()
		for v in vert_indices.keys():
			if vert_indices[v].size() <= 1:
				continue
			var vx: Vector3 = arrays[ArrayMesh.ARRAY_VERTEX][vert_indices[v][0]]
			for idx in range(1, vert_indices[v].size()):
				vx = vx.linear_interpolate(arrays[ArrayMesh.ARRAY_VERTEX][vert_indices[v][idx]], 0.5)
			for idx in vert_indices[v]:
				arrays[ArrayMesh.ARRAY_VERTEX][idx] = vx
			
		body_mesh.add_surface_from_arrays(ArrayMesh.PRIMITIVE_TRIANGLES, arrays)
		body_mesh.surface_set_material(surface, orig_body_mesh.surface_get_material(surface).duplicate(true))
		surf += 1
#	for s in range(surf - 1, -1, -1):
#		body_mesh.surface_remove(s)
	maps[modifier].image.unlock()
	maps[modifier].image_normal.unlock()
	body_mi.mesh = body_mesh
	body_mi.show()
var ch: Node
func prepare_character(x: int) -> void:
	if ch != null:
		remove_child(ch)
		ch.queue_free()
	ch = characters[x].instance()
	add_child(ch)
	ch.rotation.y = PI
	for k in maps.keys():
		maps[k].image_normal = Image.new()
		maps[k].image_normal.create_from_data(TEX_SIZE, TEX_SIZE, false, maps[k].format, maps[k].image_normal_data)
		maps[k].image = Image.new()
		maps[k].image.create_from_data(TEX_SIZE, TEX_SIZE, false, maps[k].format, maps[k].image_data)
		maps[k].value = 0.0
	body_mi = find_mesh(ch, "body")
	body_mesh = body_mi.mesh.duplicate(true)
	orig_body_mesh = body_mi.mesh.duplicate(true)
	find_same_verts()
func button_female():
	prepare_character(0)
func button_male():
	prepare_character(1)
func _ready():
	var fd = File.new()
	fd.open("res://config.bin", File.READ)
	min_point = fd.get_var()
	max_point = fd.get_var()
	min_normal = fd.get_var()
	max_normal = fd.get_var()
	maps = fd.get_var()
	fd.close()
	print("min: ", min_point, " max: ", max_point)
	prepare_character(0)
	
	assert body_mesh
	for k in maps.keys():
		var slider = HSlider.new()
		slider.rect_min_size = Vector2(180, 30)
		$VBoxContainer.add_child(slider)
		slider.connect("value_changed", self, "update_modifier", [k, slider])
		slider.focus_mode = Control.FOCUS_CLICK
		$VBoxContainer.add_child(Button.new())
	$VBoxContainer/button_female.connect("pressed", self, "button_female")
	$VBoxContainer/button_male.connect("pressed", self, "button_male")
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
