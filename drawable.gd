extends ColorRect

const TEX_SIZE = 512
var triangles : Array = []
var min_point: Vector3 = Vector3(-1, -1, -1)
var max_point: Vector3 = Vector3(-1, -1, -1)
var normals = false

func _draw():
	var default_color = Color(0.5, 0.5, 0.5, 1.0)
	default_color.r = range_lerp(0, min_point.x, max_point.x, 0.0, 1.0)
	default_color.g = range_lerp(0, min_point.y, max_point.y, 0.0, 1.0)
	default_color.b = range_lerp(0, min_point.z, max_point.z, 0.0, 1.0)
	draw_rect(Rect2(0, 0, TEX_SIZE, TEX_SIZE), default_color, true)
	for t in triangles:
		var colors = []
		var uvs = []
		for k in t:
#			print(k.shape)
#			print(k.uv)
			if normals:
				colors.push_back(Color(k.normal.x, k.normal.y, k.normal.z, 1))
			else:
				colors.push_back(Color(k.shape.x, k.shape.y, k.shape.z, 1))
			uvs.push_back(k.uv * TEX_SIZE)
		draw_polygon(PoolVector2Array(uvs), PoolColorArray(colors))
