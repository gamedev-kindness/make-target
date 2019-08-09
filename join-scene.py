import bpy
import os
import sys
import traceback
import json
from mathutils import Vector

SCENE_DIR = os.path.join(os.getcwd(), "assets")
FINAL_SCENE = os.path.join(os.getcwd(), "assets", "common-all.blend")
def copy_different_shapes(src_mesh, dest_mesh):
    dest_shape_key_index = 0
    src_shape_key_index = 0
    current_vertex_index = 0
    total_vertices = len(dest_mesh.data.vertices)
    do_once_per_vertex = False
    current_vertex = None
    src_chosen_vertices = []
    src_mwi = src_mesh.matrix_world.inverted()
    use_one_vertex = True
    increment_radius = .1

    def select_vertices(center, radius):
        src_chosen_vertices = []
        closest_vertex_index = -1
        radius_vec = center + Vector((0, 0, radius))
        # put selection sphere in local coords.
        lco = src_mwi @ center
        r   = src_mwi @ (radius_vec) - lco
        closest_length = r.length

        # select verts within radius
        for index, v in enumerate(src_mesh.data.shape_keys.key_blocks[0].data):
            is_selected = (v.co - lco).length <= r.length
            if(is_selected):
                src_chosen_vertices.append(index)
                if(use_one_vertex):
                    if((v.co - lco).length <= closest_length):
                        closest_length = (v.co - lco).length
                        closest_vertex_index = index

        # update closest vertex
        if(use_one_vertex):
            src_chosen_vertices = []
            if(closest_vertex_index > - 1):
                src_chosen_vertices.append(closest_vertex_index)

        return src_chosen_vertices

    def update_global_shapekey_indices(p_key_name):
        nonlocal src_shape_key_index, dest_shape_key_index
        for index, sk in enumerate(dest_mesh.data.shape_keys.key_blocks):
            if sk.name == p_key_name:
                dest_shape_key_index = index
        for index, sk in enumerate(src_mesh.data.shape_keys.key_blocks):
            if sk.name == p_key_name:
                src_shape_key_index = index
        print("copying %s->%s %s from %d to %d" % (src_mesh.name, dest_mesh.name, p_key_name, src_shape_key_index, dest_shape_key_index))
    def select_required_verts(vert,rad,level=0):    
        verts = []
        if(level > 20):
            return verts 
        verts = select_vertices(vert, rad)    
        if(len(verts) == 0):
            return select_required_verts(vert,rad + increment_radius, level + 1)
        else:        
            return verts

    def set_vertex_position(v_pos):
        dest_mesh.data.shape_keys.key_blocks[dest_shape_key_index].data[current_vertex_index].co = v_pos

    def update_vertex():
        nonlocal current_vertex_index, do_once_per_vertex, src_chosen_vertices, current_vertex
        if(current_vertex_index >= total_vertices ):
            print("too many vertices")
            return
        print("here")
        if(do_once_per_vertex):
            current_vertex = dest_mesh.matrix_world @ dest_mesh.data.shape_keys.key_blocks[0].data[current_vertex_index].co
            src_chosen_vertices = select_required_verts(current_vertex,0)
            do_once_per_vertex = False
        if(len(src_chosen_vertices) == 0):
            print("Failed to find surrounding vertices | Try increasing increment radius | vertex index ", current_vertex_index, " at shape key index ", src_shape_key_index)
            current_vertex_index += 1
            return
        else:
            print("%d %d" % (len(src_chosen_vertices), current_vertex_index))
        result_position = Vector()
        for v in src_chosen_vertices:
            result_position +=  src_mesh.data.shape_keys.key_blocks[0].data[v].co
        result_position /= len(src_chosen_vertices)
        result_position2 = Vector()
        for v in src_chosen_vertices:
            result_position2 += src_mesh.data.shape_keys.key_blocks[src_shape_key_index].data[v].co
            result_position2 /= len(src_chosen_vertices)
            result = result_position2 - result_position + current_vertex
            set_vertex_position(result)


    for src_shape_key_iter in src_mesh.data.shape_keys.key_blocks:
        valid_shape = False
        for dest_shape_key_iter in dest_mesh.data.shape_keys.key_blocks:
            if(src_shape_key_iter.name == dest_shape_key_iter.name):
                valid_shape = True
        if not valid_shape:
            dest_mesh.shape_key_add(name=src_shape_key_iter.name)
            print(src_shape_key_iter.name)
    print("total verts: " + str(total_vertices))
    while(current_vertex_index < total_vertices):
        do_once_per_vertex = True
        for shape_key_iter in src_mesh.data.shape_keys.key_blocks:
            key_name = shape_key_iter.name
            update_global_shapekey_indices(shape_key_iter.name)
            if dest_shape_key_index == 0 or src_shape_key_index == 0:
                print("bad shape")
                continue
            update_vertex()
        current_vertex_index += 1
def copy_same_shapes(src_mesh, dest_mesh):
    total_vertices = len(dest_mesh.data.vertices)
    for src_shape_key_iter in src_mesh.data.shape_keys.key_blocks:
        valid_shape = False
        for dest_shape_key_iter in dest_mesh.data.shape_keys.key_blocks:
            if(src_shape_key_iter.name == dest_shape_key_iter.name):
                valid_shape = True
        if not valid_shape:
            dest_mesh.shape_key_add(name=src_shape_key_iter.name)
            print(src_shape_key_iter.name)
    print("total verts: " + str(total_vertices))
    for shape_key_iter in src_mesh.data.shape_keys.key_blocks:
        p_key_name = shape_key_iter.name
        for index, sk in enumerate(dest_mesh.data.shape_keys.key_blocks):
            if sk.name == p_key_name:
                dest_shape_key_index = index
        for index, sk in enumerate(src_mesh.data.shape_keys.key_blocks):
            if sk.name == p_key_name:
                src_shape_key_index = index
        for v in range(len(dest_mesh.data.vertices)):
                d = src_mesh.data.shape_keys.key_blocks[src_shape_key_index].data[v].co
                dest_mesh.data.shape_keys.key_blocks[dest_shape_key_index].data[v].co = d
def copy_shapes(src_mesh, dest_mesh):
    total_vertices_dst = len(dest_mesh.data.vertices)
    total_vertices_src = len(src_mesh.data.vertices)
    if total_vertices_dst == total_vertices_src:
        print("copy from %s to %s, same" % (src_mesh.name, dest_mesh.name))
        copy_same_shapes(src_mesh, dest_mesh)
    else:
        print("copy from %s to %s, different" % (src_mesh.name, dest_mesh.name))
        copy_different_shapes(src_mesh, dest_mesh)
def main():
        base_config = {}
        if os.path.exists(os.path.join(SCENE_DIR, "config.json")):
            with open(os.path.join(SCENE_DIR, "config.json")) as config_file:
                base_config = json.load(config_file)
        item_abspath = os.path.join(SCENE_DIR, base_config["files"][0])
        bpy.ops.wm.open_mainfile(filepath=item_abspath)
        bases = []
        for ob in bpy.data.objects:
            if ob.name == "base" or ob.name.endswith("_helper"):
                bases.append(ob)
        for k in base_config["files"][1:]:
            item_abspath = os.path.join(SCENE_DIR, k)
            with bpy.data.libraries.load(item_abspath, link=False) as (data_from, data_to):
                data_to.objects = [name for name in data_from.objects if name == "base" or name.endswith("_helper")]
            for obj in data_to.objects:
                 for ob in bases:
                    if obj.name.startswith(ob.name):
                         copy_shapes(obj, ob)
        for ob in bpy.data.objects:
            if ob.name.endswith("_helper"):
                ob.hide_set(False)
                ob.hide_render = False
                ob.hide_viewport = False
        bpy.data.objects["base"].select_set(True)
        bpy.context.view_layer.objects.active = bpy.data.objects["base"]
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        for ob in bpy.data.objects:
            ob.select_set(False)
        for ob in bpy.data.objects:
            if ob.name.endswith("_helper"):
                copy_shapes(bpy.data.objects["base"], ob)
        bpy.context.view_layer.objects.active = bpy.data.objects["base"]
        bpy.ops.wm.save_mainfile(filepath=FINAL_SCENE, check_existing=False)

def run_with_abort(function):
    """Runs a function such that an abort causes blender to quit with an error
    code. Otherwise, even a failed script will allow the Makefile to continue
    running"""
    try:
        function()
    except:
        traceback.print_exc()
        exit(1)


if __name__ == "__main__":
    run_with_abort(main)

