import bpy
import os
import sys
import traceback
import json
from mathutils import Vector
SOURCE_SCENE = os.path.join(os.getcwd(), "assets", "common-all.blend")
EXPORT_DIR = os.path.join(os.getcwd(), "assets", "exports")
SCENE_DIR = os.path.join(os.getcwd(), "assets")
CHARACTER_DIR = os.path.join(os.getcwd(), "characters")
SHAPES_PER_PART = 12
def make_part_list(shapes):
    part_no = 0
    ret = {}
    part_shapes = []
    for k in shapes:
        if len(part_shapes) < SHAPES_PER_PART:
            part_shapes.append(k)
        else:
            fn = "common_part%d.blend" % (part_no)
            ret[fn] = part_shapes
            part_shapes = [k]
            part_no += 1
    ret["common_part%d.blend" % (part_no)] = part_shapes
    return ret
def export_escn(out_file, config):
    """Fake the export operator call"""
    import io_scene_godot
    io_scene_godot.export(out_file, config)
def main():
        base_config = {}
        shape_list = []
        result_data = {}
        if os.path.exists(os.path.join(CHARACTER_DIR, "data.json")):
            result_data = json.load(open(os.path.join(CHARACTER_DIR, "data.json")))
        result_data["files"] = []
        if os.path.exists(os.path.join(SCENE_DIR, "config.json")):
            with open(os.path.join(SCENE_DIR, "config.json")) as config_file:
                base_config = json.load(config_file)
        else:
            base_config = {
                        "outpath": "exports",
                        "collections": [],
                        "use_visible_objects": True,
                        "use_export_selected": False,
                        "use_mesh_modifiers": True,
                        "use_exclude_ctrl_bone": False,
                        "use_export_animation": True,
                        "use_export_material": True,
                        "use_export_shape_key": True,
                        "use_stashed_action": True,
                        "use_beta_features": True,
                        "generate_external_material": False,
                        "animation_modes": "ACTIONS",
                        "object_types": {"EMPTY", "ARMATURE", "GEOMETRY"}
                     }
        bpy.ops.wm.open_mainfile(filepath=SOURCE_SCENE)
        if not os.path.exists(EXPORT_DIR):
            os.makedirs(EXPORT_DIR)

        for shape_key_iter in bpy.data.objects["base"].data.shape_keys.key_blocks:
            if shape_key_iter.name != "Basis":
                shape_list.append(shape_key_iter.name)
        split_list = make_part_list(shape_list)
        for fn in split_list.keys():
            bpy.ops.wm.save_mainfile(filepath=os.path.join(EXPORT_DIR, fn), check_existing=False)
        for fn in split_list.keys():
            bpy.ops.wm.open_mainfile(filepath=os.path.join(EXPORT_DIR, fn))
            for ob in bpy.data.objects:
                if ob.name == "base" or ob.name.endswith("_helper"):
                    for shape_key_iter in ob.data.shape_keys.key_blocks:
                        if not shape_key_iter.name in split_list[fn]:
                            ob.shape_key_remove(shape_key_iter)
            bpy.ops.wm.save_mainfile(filepath=os.path.join(EXPORT_DIR, fn), check_existing=False)
            out_path = os.path.join(
                CHARACTER_DIR,
                fn.replace('.blend', '.escn')
                )
            export_escn(out_path, base_config)
            result_data["files"].append(os.path.join("characters", fn.replace('.blend', '.escn')))
        print("Exported to {}".format(os.path.abspath(out_path)))
        fd = open(os.path.join(CHARACTER_DIR, "data.json"), "w")
        fd.write(json.dumps(result_data, indent=4, sort_keys=True))
        fd.close()
        print("Exported to {}".format(os.path.abspath(out_path)))

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
