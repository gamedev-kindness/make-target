extends Control

var mesh: ArrayMesh
var ch: Node
const TEX_SIZE: int = 512
var nshapes = []
var draw_data: = {}
var min_point = Vector3()
var max_point = Vector3()
var min_normal = Vector3()
var max_normal = Vector3()
var maps = {}

func find_mesh(base: Node) -> ArrayMesh:
	var queue = [base]
	var am: ArrayMesh
	while queue.size() > 0:
		var item = queue[0]
		queue.pop_front()
		if item is MeshInstance:
			am = item.mesh.duplicate(true)
			break
		for c in item.get_children():
			queue.push_back(c)
	return am
func find_min_max():
	min_point = mesh.surface_get_blend_shape_arrays(0)[0][ArrayMesh.ARRAY_VERTEX][0] - mesh.surface_get_arrays(0)[ArrayMesh.ARRAY_VERTEX][0]
	max_point = mesh.surface_get_blend_shape_arrays(0)[0][ArrayMesh.ARRAY_VERTEX][0] - mesh.surface_get_arrays(0)[ArrayMesh.ARRAY_VERTEX][0]
	for sc in range(mesh.get_surface_count()):
		var bshapes: Array = mesh.surface_get_blend_shape_arrays(sc).duplicate(true)
		var arrays: Array = mesh.surface_get_arrays(sc).duplicate(true)
		for src in bshapes:
			for index in range(arrays[ArrayMesh.ARRAY_VERTEX].size()):
				var v: Vector3 = src[ArrayMesh.ARRAY_VERTEX][index] - arrays[ArrayMesh.ARRAY_VERTEX][index]
				var n: Vector3 = src[ArrayMesh.ARRAY_NORMAL][index] - arrays[ArrayMesh.ARRAY_NORMAL][index]
				for ipos in range(2):
					if min_point[ipos] > v[ipos]:
						min_point[ipos] = v[ipos] 
					if max_point[ipos] < v[ipos]:
						max_point[ipos] = v[ipos]
					if min_normal[ipos] > n[ipos]:
						min_normal[ipos] = n[ipos] 
					if max_normal[ipos] < n[ipos]:
						max_normal[ipos] = n[ipos]
	print("min: ", min_point, "max: ", max_point)
func check_triangle(verts: Array) -> bool:
	var uv1 = verts[0].uv
	var uv2 = verts[1].uv
	var uv3 = verts[2].uv
	var v1 = uv1 - uv3
	var v2 = uv1 - uv3
	if v1.length() * TEX_SIZE < 1.2:
		return false
	if v2.length() * TEX_SIZE < 1.2:
		return false
	var sumdata = Vector3()
	for k in range(2):
		for ks in range(verts[k].shape.size()):
			sumdata += verts[k].shape[ks]
	if sumdata.length() < 0.001:
		return false
	return true
func _ready():
	var morphs = []
	var skipped : = 0
	var ntriangles : = 0
	ch = load("res://characters/common.tscn").instance()
	add_child(ch)
	mesh = find_mesh(ch)
	if !mesh:
		return
	find_min_max()
	for sc in range(mesh.get_surface_count()):
		var bshapes: Array = mesh.surface_get_blend_shape_arrays(sc)
		var arrays: Array = mesh.surface_get_arrays(sc)
		print("vertices: ", arrays[ArrayMesh.ARRAY_VERTEX].size())
		print("indices: ", arrays[ArrayMesh.ARRAY_INDEX].size())
		print("surf: ", sc, " shapes: ", bshapes.size())
		for bsc in range(bshapes.size()):
			print("shape: ", bsc, " size: ", bshapes[bsc].size(), " name: ", mesh.get_blend_shape_name(bsc))
			print("vertices: ", bshapes[bsc][ArrayMesh.ARRAY_VERTEX].size())
			print("indices: ", bshapes[bsc][ArrayMesh.ARRAY_INDEX].size())
		nshapes.push_back(bshapes.size())
		var triangles = []
		for idx in range(0, arrays[ArrayMesh.ARRAY_INDEX].size(), 3):
			var verts = []
			for t in range(3):
				var index_base = arrays[ArrayMesh.ARRAY_INDEX][idx + t]
				var vertex_base = arrays[ArrayMesh.ARRAY_VERTEX][index_base]
				var normal_base = arrays[ArrayMesh.ARRAY_NORMAL][index_base]
				var uv_base = arrays[ArrayMesh.ARRAY_TEX_UV][index_base]
				var index_shape = []
				var vertex_shape = []
				var normal_shape = []
				var uv_shape = []
				for bsc in range(bshapes.size()):
					index_shape.push_back(bshapes[bsc][ArrayMesh.ARRAY_INDEX][idx + t])
					var index = index_shape[index_shape.size() - 1]
					if index != index_base:
						print("index mismatch", bsc, " ", index_base, " ", index)
					var vertex_mod = bshapes[bsc][ArrayMesh.ARRAY_VERTEX][index] - vertex_base
					var normal_mod = bshapes[bsc][ArrayMesh.ARRAY_NORMAL][index] - normal_base
#					if idx == 0 && sc == 0 && bsc == 0:
#						min_point = vertex_mod
#						max_point = vertex_mod
#					else:
#						for ipos in range(2):
#							if min_point[ipos] > vertex_mod[ipos]:
#								min_point[ipos] = vertex_mod[ipos] 
#							if max_point[ipos] < vertex_mod[ipos]:
#								max_point[ipos] = vertex_mod[ipos] 
					vertex_shape.push_back(vertex_mod)
					normal_shape.push_back(normal_mod)
					uv_shape.push_back(bshapes[bsc][ArrayMesh.ARRAY_TEX_UV][index])
					if (uv_shape[uv_shape.size() - 1] - uv_base).length() != 0:
						print("uv mismatch", bsc, " ", idx)
				var vdata = {}
				vdata.shape = vertex_shape
				vdata.normal = normal_shape
				vdata.uv = uv_base
				verts.push_back(vdata)
#			var uv1 = verts[0].uv
#			var uv2 = verts[1].uv
#			var uv3 = verts[2].uv
#			var v1 = uv1 - uv3
#			var v2 = uv1 - uv3
#			if v1.length() * TEX_SIZE < 1.5:
#				skipped += 1
#				continue
#			if v2.length() * TEX_SIZE < 1.5:
#				skipped += 1
#				continue
#			var sumdata = Vector3()
#			for k in range(2):
#				for ks in range(verts[k].shape.size()):
#					sumdata += verts[k].shape[ks]
#			if sumdata.length() == 0:
#				skipped += 1
#				continue
			if check_triangle(verts):
				triangles.push_back(verts)
				ntriangles += 1
			else:
				skipped += 1
		morphs.push_back(triangles)
	for m in range(morphs.size()):
		var ns = nshapes[m]
		for t in range(morphs[m].size()):
			for v in range(morphs[m][t].size()):
				for s in range(morphs[m][t][v].shape.size()):
					for u in range(2):
						var cd : float = max_point[u] - min_point[u]
						var ncd : float = max_normal[u] - min_normal[u]
						var d = morphs[m][t][v].shape[s][u]
#						morphs[m][t][v].shape[s][u] = (d - min_point[u]) / cd
						morphs[m][t][v].shape[s][u] = (d - min_point[u]) / cd
						var ew = morphs[m][t][v].shape[s][u] * cd + min_point[u]
						assert abs(ew - d) < 0.001
						morphs[m][t][v].normal[s][u] = (morphs[m][t][v].normal[s][u] - min_normal[u]) / ncd
#						morphs[m][t][v].shape[s][u] = range_lerp(morphs[m][t][v].shape[s][u], min_point[u], max_point[u], 0.0, 1.0)
	for m in range(morphs.size()):
		draw_data[m] = {}
		var ns = nshapes[m]
		for sh in range(ns):
			draw_data[m][sh] = {"triangles": []}
			for t in range(morphs[m].size()):
				var tri : = []
				var midp = Vector2()
				var sp = Vector3()
				
				for v in range(morphs[m][t].size()):
					midp += morphs[m][t][v].uv
				midp /= 3.0
				for v in range(morphs[m][t].size()):
					var pt = morphs[m][t][v].uv - midp
					var dpt = pt.normalized() * (3.5 / TEX_SIZE)
					tri.push_back({"uv": morphs[m][t][v].uv + dpt, "shape": morphs[m][t][v].shape[sh], "normal": morphs[m][t][v].normal[sh]})
				draw_data[m][sh].triangles.push_back(tri)
	$gen/drawable.triangles = draw_data[0][0].triangles
	$gen/drawable.min_point = min_point
	$gen/drawable.max_point = max_point
	$gen/drawable.normals = false
#	print("done ", mesh.get_surface_count(), " ", mesh.get_blend_shape_count(), " ", min_point, " ", max_point, " added: ", ntriangles, " skipped: ", skipped)
var surface : = 0
var shape : = 0
var exit_delay : = 3.0
var draw_delay : = 2.0
func save_viewport():
	var viewport: Viewport = $gen
	var vtex : = viewport.get_texture()
	var tex_img : = vtex.get_data()
	var fn = ""
	if !maps.has(mesh.get_blend_shape_name(shape)):
		maps[mesh.get_blend_shape_name(shape)] = {}
	if $gen/drawable.normals:
		fn = "res://normal_" + mesh.get_blend_shape_name(shape) + "_" + str(surface) + ".png"
		maps[mesh.get_blend_shape_name(shape)].fn_normal = fn
		maps[mesh.get_blend_shape_name(shape)].image_normal_data = tex_img.duplicate(true).get_data()
	else:
		fn = "res://normal_" + mesh.get_blend_shape_name(shape) + "_" + str(surface) + ".png"
		maps[mesh.get_blend_shape_name(shape)].fn = fn
		maps[mesh.get_blend_shape_name(shape)].image_data = tex_img.duplicate(true).get_data()
		maps[mesh.get_blend_shape_name(shape)].format = tex_img.get_format()
	tex_img.save_png(fn)

func _process(delta):
	if surface == draw_data.size():
		if exit_delay > 0:
			exit_delay -= delta
			print(exit_delay)
		else:
			var fd = File.new()
			fd.open("res://config.bin", File.WRITE)
			fd.store_var(min_point)
			fd.store_var(max_point)
			fd.store_var(min_normal)
			fd.store_var(max_normal)
			fd.store_var(maps)
			fd.close()
			get_tree().quit()
	elif shape == draw_data[surface].size():
		shape = 0
		surface += 1
		draw_delay = 2.0
		$gen_maps/ProgressBar.value = 100.0
	else:
		$gen_maps/ProgressBar.value = 100.0 * shape / draw_data[surface].size()
		print("value ", $gen_maps/ProgressBar.value)
		if draw_delay > 0:
			draw_delay -= delta
		else:
			save_viewport()
			if $gen/drawable.normals:
				shape += 1
			draw_delay = 2.0
			print("shape ", shape)
			if shape < draw_data[surface].size():
				$gen/drawable.normals = !$gen/drawable.normals
				if $gen/drawable.normals:
					$gen/drawable.min_point = min_normal
					$gen/drawable.max_point = max_normal
				else:
					$gen/drawable.min_point = min_point
					$gen/drawable.max_point = max_point
				$gen/drawable.triangles = draw_data[surface][shape].triangles
				$gen/drawable.update()
