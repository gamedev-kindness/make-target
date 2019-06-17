extends Control

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
var mesh: ArrayMesh
var ch: Node
const TEX_SIZE: int = 512
var nshapes = []
var draw_data: = {}
var min_point = Vector3()
var max_point = Vector3()
func _ready():
	var morphs = []
	ch = load("res://characters/common.tscn").instance()
	add_child(ch)
	var queue = [ch]
	while queue.size() > 0:
		var item = queue[0]
		queue.pop_front()
		if item is MeshInstance:
			mesh = item.mesh.duplicate(true)
			break
		for c in item.get_children():
			queue.push_back(c)
	var skipped : = 0
	var ntriangles : = 0
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
				var uv_base = arrays[ArrayMesh.ARRAY_TEX_UV][index_base]
				var index_shape = []
				var vertex_shape = []
				var uv_shape = []
				for bsc in range(bshapes.size()):
					index_shape.push_back(bshapes[bsc][ArrayMesh.ARRAY_INDEX][idx + t])
					var index = index_shape[index_shape.size() - 1]
					if index != index_base:
						print("index mismatch", bsc, " ", index_base, " ", index)
					var vertex_mod = bshapes[bsc][ArrayMesh.ARRAY_VERTEX][index] - vertex_base
					if idx == 0 && sc == 0 && bsc == 0:
						min_point = vertex_mod
						max_point = vertex_mod
					else:
						for ipos in range(2):
							if min_point[ipos] > vertex_mod[ipos]:
								min_point[ipos] = vertex_mod[ipos] 
							if max_point[ipos] < vertex_mod[ipos]:
								max_point[ipos] = vertex_mod[ipos] 
					vertex_shape.push_back(vertex_mod)
					uv_shape.push_back(bshapes[bsc][ArrayMesh.ARRAY_TEX_UV][index])
					if (uv_shape[uv_shape.size() - 1] - uv_base).length() != 0:
						print("uv mismatch", bsc, " ", idx)
				var vdata = {}
				vdata.shape = vertex_shape
				vdata.uv = uv_base
				verts.push_back(vdata)
			var uv1 = verts[0].uv
			var uv2 = verts[1].uv
			var uv3 = verts[2].uv
			var v1 = uv1 - uv3
			var v2 = uv1 - uv3
			if v1.length() * TEX_SIZE < 1.5:
				skipped += 1
				continue
			if v2.length() * TEX_SIZE < 1.5:
				skipped += 1
				continue
			var sumdata = Vector3()
			for k in range(2):
				for ks in range(verts[k].shape.size()):
					sumdata += verts[k].shape[ks]
			if sumdata.length() == 0:
				skipped += 1
				continue
			triangles.push_back(verts)
			ntriangles += 1
		morphs.push_back(triangles)
	for m in range(morphs.size()):
		var ns = nshapes[m]
		for t in range(morphs[m].size()):
			for v in range(morphs[m][t].size()):
				for s in range(morphs[m][t][v].shape.size()):
					for u in range(2):
						morphs[m][t][v].shape[s][u] = range_lerp(morphs[m][t][v].shape[s][u], min_point[u], max_point[u], 0.0, 1.0)
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
					tri.push_back({"uv": morphs[m][t][v].uv + dpt, "shape": morphs[m][t][v].shape[sh]})
				draw_data[m][sh].triangles.push_back(tri)
	print("done ", mesh.get_surface_count(), " ", mesh.get_blend_shape_count(), " ", min_point, " ", max_point, " added: ", ntriangles, " skipped: ", skipped)
var surf : = 0
var shape : = 0
func _draw():
	var default_color = Color()
	default_color.r = range_lerp(0, min_point.x, max_point.x, 0.0, 1.0)
	default_color.g = range_lerp(0, min_point.y, max_point.y, 0.0, 1.0)
	default_color.b = range_lerp(0, min_point.z, max_point.z, 0.0, 1.0)
	draw_rect(Rect2(0, 0, TEX_SIZE, TEX_SIZE), default_color, true)
	for t in draw_data[surf][shape].triangles:
		var colors = []
		var uvs = []
		for k in t:
#			print(k.shape)
#			print(k.uv)
			colors.push_back(Color(k.shape.x, k.shape.y, k.shape.z, 1))
			uvs.push_back(k.uv * TEX_SIZE)
		draw_polygon(PoolVector2Array(uvs), PoolColorArray(colors))
	print(shape)
	if draw_data[surf].size() - 1 > shape:
		save_viewport()
		shape += 1
var update_to = 3.0
func save_viewport():
	var viewport : = get_viewport()
	var vtex : = viewport.get_texture()
	var tex_img : = vtex.get_data()
	tex_img.save_png("res://vertex_" + str(shape) + ".png")
func _process(delta):
	update_to -= delta
	if update_to < 0:
		update()
		update_to = 3.0
