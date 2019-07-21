extends Spatial

onready var characters = [load("res://characters/female_2018.escn"), load("res://characters/male_2018.escn")]
var body_mi: MeshInstance
var body_mesh: ArrayMesh
var orig_body_mesh: ArrayMesh
var cloth_mis: Array = []
var cloth_meshes: Array = []
var cloth_orig_meshes: Array = []
var cloth_names: Array = ["dress", "panties", "suit"]
var min_point: Vector3 = Vector3()
var max_point: Vector3 = Vector3()
var min_normal: Vector3 = Vector3()
var max_normal: Vector3 = Vector3()
var maps = {}
var vert_indices = {}
var _vert_indices = {}
var controls = {}

var helper_names : = ["skirt"]

func toggle_clothes(mi: MeshInstance, orig_mesh: ArrayMesh):
	if !mi.visible:
		print("mod start")
		modify_mesh(orig_mesh, mi, {})
		print("mod end")
	mi.visible = !mi.visible

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
func modify_mesh(orig_mesh: ArrayMesh, mi: MeshInstance, v_indices: Dictionary):
	var should_show : = false
	if mi.visible:
		mi.hide()
		should_show = true
	mi.mesh = null
	for k in maps.keys():
		maps[k].image.lock()
		maps[k].image_normal.lock()
	var surf : = 0
	var mod_mesh = ArrayMesh.new()
	var mrect: Rect2
	for k in maps.keys():
		if maps[k].value > 0.0001:
			if mrect:
				mrect = mrect.merge(maps[k].rect)
			else:
				mrect = maps[k].rect
	for surface in range(orig_mesh.get_surface_count()):
		var arrays: Array = orig_mesh.surface_get_arrays(surface)
		var uv_index: int = ArrayMesh.ARRAY_TEX_UV
		if arrays[ArrayMesh.ARRAY_TEX_UV2] && arrays[ArrayMesh.ARRAY_TEX_UV2].size() > 0:
			uv_index = ArrayMesh.ARRAY_TEX_UV2
		for index in range(arrays[ArrayMesh.ARRAY_VERTEX].size()):
			var v: Vector3 = arrays[ArrayMesh.ARRAY_VERTEX][index]
			var n: Vector3 = arrays[ArrayMesh.ARRAY_NORMAL][index]
			var uv: Vector2 = arrays[uv_index][index]
			if !mrect.has_point(uv):
				continue
			var diff : = Vector3()
			var diffn : = Vector3()
			for k in maps.keys():
				if !maps[k].rect.has_point(uv) || abs(maps[k].value) < 0.0001:
					continue
				var pos: Vector2 = Vector2(uv.x * maps[k].width, uv.y * maps[k].height)
				var offset: Color = maps[k].image.get_pixelv(pos)
				var offsetn: Color = maps[k].image_normal.get_pixelv(pos)
				var pdiff: Vector3 = Vector3(offset.r, offset.g, offset.b)
				var ndiff: Vector3 = Vector3(offsetn.r, offsetn.g, offsetn.b)
				for u in range(2):
					diff[u] = range_lerp(pdiff[u], 0.0, 1.0, min_point[u], max_point[u]) * maps[k].value
					diffn[u] = range_lerp(ndiff[u], 0.0, 1.0, min_normal[u], max_normal[u]) * maps[k].value
					if abs(diff[u]) < 0.0001:
						diff[u] = 0
				v -= diff
				n -= diffn
			arrays[ArrayMesh.ARRAY_VERTEX][index] = v
			arrays[ArrayMesh.ARRAY_NORMAL][index] = n.normalized()
		for v in v_indices.keys():
			if v_indices[v].size() <= 1:
				continue
			var vx: Vector3 = arrays[ArrayMesh.ARRAY_VERTEX][v_indices[v][0]]
			for idx in range(1, v_indices[v].size()):
				vx = vx.linear_interpolate(arrays[ArrayMesh.ARRAY_VERTEX][v_indices[v][idx]], 0.5)
			for idx in v_indices[v]:
				arrays[ArrayMesh.ARRAY_VERTEX][idx] = vx
			
		mod_mesh.add_surface_from_arrays(ArrayMesh.PRIMITIVE_TRIANGLES, arrays)
		if orig_mesh.surface_get_material(surface):
			mod_mesh.surface_set_material(surface, orig_mesh.surface_get_material(surface).duplicate(true))
		surf += 1
	for k in maps.keys():
		maps[k].image.unlock()
		maps[k].image_normal.unlock()
	mi.mesh = mod_mesh
	if should_show:
		mi.show()
func update_modifier(value: float, modifier: String):
	var val = value / 100.0
	val = clamp(val, 0.0, 1.0)
	maps[modifier].value = val
	print(modifier, " ", val)
	modify_mesh(orig_body_mesh, body_mi, _vert_indices)
	for k in range(cloth_mis.size()):
		if cloth_mis[k].visible:
			modify_mesh(cloth_orig_meshes[k], cloth_mis[k], {})
func update_slider(value: float, control: String, slider: HSlider):
	var modifier = ""
	if value >= 0:
		modifier = controls[control].plus
		maps[controls[control].minus].value = 0.0
	else:
		value = -value
		modifier = controls[control].minus
		maps[controls[control].plus].value = 0.0
	update_modifier(value, modifier)
func triangulate_uv(v0: Vector3, vs: PoolVector3Array, uvs: PoolVector2Array) -> Vector2:
	assert vs.size() == 3
	var d1: float = v0.distance_to(vs[0])
	var d2: float = v0.distance_to(vs[1])
	var d3: float = v0.distance_to(vs[2])
	var ln = max(d1, max(d2, d3))
	var v = Vector3(d1/ln, d2/ln, d3/ln)
	var midp : Vector2 = (uvs[0] + uvs[1] + uvs[2]) * 1.0 / 3.0
	var uv: Vector2 = midp.linear_interpolate(uvs[0], v.x) + midp.linear_interpolate(uvs[1], v.y) + midp.linear_interpolate(uvs[2], v.z)
	uv /= 3.0
	return uv
func prepare_cloth(body_mi: MeshInstance, cloth_mi: MeshInstance):
	var arrays_cloth: Array = cloth_mi.mesh.surface_get_arrays(0)
	if arrays_cloth[ArrayMesh.ARRAY_TEX_UV2] == null:
		var d: PoolVector2Array = PoolVector2Array()
		d.resize(arrays_cloth[ArrayMesh.ARRAY_VERTEX].size())
		assert d.size() > 0
		arrays_cloth[ArrayMesh.ARRAY_TEX_UV2] = d
	var arrays_body: Array = body_mi.mesh.surface_get_arrays(0)
	var tmp: Dictionary = {}
	for vcloth in range(arrays_cloth[ArrayMesh.ARRAY_VERTEX].size()):
		for vbody in range(arrays_body[ArrayMesh.ARRAY_VERTEX].size()):
			var vc: Vector3 = arrays_cloth[ArrayMesh.ARRAY_VERTEX][vcloth]
			var vb: Vector3 = arrays_body[ArrayMesh.ARRAY_VERTEX][vbody]
			if vc.distance_to(vb) < 0.02:
				if tmp.has(vcloth):
					tmp[vcloth].push_back(vbody)
				else:
					tmp[vcloth] = [vbody]
	for k in tmp.keys():
		var vc: Vector3 = arrays_cloth[ArrayMesh.ARRAY_VERTEX][k]
		var res: Array = []
		for v in tmp[k]:
			var vb: Vector3 = arrays_body[ArrayMesh.ARRAY_VERTEX][v]
			var d1 = vc.distance_squared_to(vb)
			if res.size() >= 3:
				for mv in range(res.size()):
					var vb1: Vector3 = arrays_body[ArrayMesh.ARRAY_VERTEX][res[mv]]
					var d2 = vc.distance_squared_to(vb1)
					if d1 < d2 && !v in res:
						res[mv] = v
			else:
				if ! v in res:
					res.push_back(v)
		tmp[k] = res
		if res.size() == 3:
			var vtx: Vector3 = arrays_cloth[ArrayMesh.ARRAY_VERTEX][k]
			var bverts = PoolVector3Array()
			var buvs = PoolVector2Array()
			for e in res:
				var vb: Vector3 = arrays_body[ArrayMesh.ARRAY_VERTEX][e]
				var ub: Vector2 = arrays_body[ArrayMesh.ARRAY_TEX_UV][e]
				bverts.push_back(vb)
				buvs.push_back(ub)
			arrays_cloth[ArrayMesh.ARRAY_TEX_UV2][k] = triangulate_uv(vtx, bverts, buvs)
	var new_mesh : = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_cloth)
	cloth_mi.mesh = new_mesh
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
		maps[k].image_normal.create_from_data(maps[k].width, maps[k].height, false, maps[k].format, maps[k].image_normal_data)
		maps[k].image = Image.new()
		maps[k].image.create_from_data(maps[k].width, maps[k].height, false, maps[k].format, maps[k].image_data)
		maps[k].value = 0.0
	body_mi = find_mesh(ch, "body")
	body_mesh = body_mi.mesh.duplicate(true)
	orig_body_mesh = body_mi.mesh.duplicate(true)
	_vert_indices = vert_indices[x]
	cloth_meshes.clear()
	cloth_mis.clear()
	cloth_orig_meshes.clear()
	for c in $s/VBoxContainer/clothes.get_children():
		$s/VBoxContainer/clothes.remove_child(c)
		c.queue_free()
	$s/VBoxContainer/clothes.add_child(HSeparator.new())
	var clothes_label = Label.new()
	clothes_label.text = "Clothes"
	$s/VBoxContainer/clothes.add_child(clothes_label)
	for cloth in cloth_names:
		var cloth_mi : = find_mesh(ch, cloth)
		if !cloth_mi:
			continue
		cloth_mis.push_back(cloth_mi)
		prepare_cloth(body_mi, cloth_mi)
		cloth_meshes.push_back(cloth_mi.mesh)
		cloth_orig_meshes.push_back(cloth_mi.mesh.duplicate(true))
		var cloth_button = Button.new()
		cloth_button.text = cloth_mi.name
		$s/VBoxContainer/clothes.add_child(cloth_button)
		cloth_button.connect("pressed", self, "toggle_clothes", [cloth_mi, cloth_orig_meshes[cloth_orig_meshes.size() - 1]])
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
	vert_indices = fd.get_var()
	fd.close()
	print("min: ", min_point, " max: ", max_point)
	for k in maps.keys():
		print(k, ": ", maps[k].rect)
	
var state : = 0
func build_contols():
	for k in maps.keys():
		if k.ends_with("_plus"):
			var cname = k.replace("_plus", "")
			if !controls.has(cname):
				controls[cname] = {}
			controls[cname].plus = k
		elif k.ends_with("_minus"):
			var cname = k.replace("_minus", "")
			if !controls.has(cname):
				controls[cname] = {}
			controls[cname].minus = k
		else:
			var cname = k
			controls[cname] = {}
			controls[cname].plus = k
	for k in controls.keys():
		var ok = true
		for m in helper_names:
			if k.begins_with(m + "_"):
				ok = false
				break
		if !ok:
			continue
		var l = Label.new()
		l.text = k
		$s/VBoxContainer.add_child(l)
		var slider : = HSlider.new()
		slider.rect_min_size = Vector2(180, 30)
		if controls[k].plus && controls[k].minus:
			slider.min_value = -100
			slider.max_value = 100
		else:
			slider.min_value = 0
			slider.max_value = 100
		$s/VBoxContainer.add_child(slider)
		slider.connect("value_changed", self, "update_slider", [k, slider])
		slider.focus_mode = Control.FOCUS_CLICK
			
func _process(delta):
	match(state):
		0:
#			find_same_verts()
			prepare_character(0)
			state = 1
		1:
#			$Panel.hide()
			assert body_mesh
			build_contols()
			$s/VBoxContainer/button_female.connect("pressed", self, "button_female")
			$s/VBoxContainer/button_male.connect("pressed", self, "button_male")
			state = 2
