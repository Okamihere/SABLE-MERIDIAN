"""Build the low-poly Contrarregra character in Blender and export a GLB."""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "characters"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = OUT / ".source"
SOURCE.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

character = bpy.data.collections.new("Contrarregra | character")
bpy.context.scene.collection.children.link(character)
preview = bpy.data.collections.new("Preview | lights and camera")
bpy.context.scene.collection.children.link(preview)
parts = []


def material(name, color, metallic=0.0, roughness=0.8):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    return mat


black = material("01 | stage velvet", (0.018, 0.021, 0.033))
black_light = material("02 | charcoal seams", (0.07, 0.075, 0.10))
ivory = material("03 | old ivory", (0.78, 0.73, 0.59))
bone = material("04 | porcelain mask", (0.93, 0.88, 0.74))
skin = material("05 | muted skin", (0.33, 0.25, 0.23))
gold = material("06 | antique brass", (0.67, 0.43, 0.14), 0.65, 0.36)
red = material("07 | quiet crimson", (0.26, 0.035, 0.055))
eye = material("08 | visible eye", (0.64, 0.37, 0.13), 0.3, 0.35)


def keep(obj, name, mat):
    obj.name = name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    character.objects.link(obj)
    obj.data.materials.append(mat)
    parts.append(obj)
    return obj


def cube(name, center, scale, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = keep(bpy.context.object, name, mat)
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("small hard edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        obj.modifiers.new("weighted corners", "WEIGHTED_NORMAL")
    return obj


def ico(name, center, radius, mat, subdivisions=1, scale=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=center)
    obj = keep(bpy.context.object, name, mat)
    if scale:
        obj.scale = scale
    return obj


def cone(name, center, bottom, top, depth, mat, sides=8):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=bottom, radius2=top, depth=depth, location=center)
    return keep(bpy.context.object, name, mat)


def segment(name, start, end, radius, mat, sides=6):
    midpoint = (Vector(start) + Vector(end)) / 2
    direction = Vector(end) - Vector(start)
    obj = cone(name, midpoint, radius, radius, direction.length, mat, sides)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def polygon(name, vertices, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    character.objects.link(obj)
    mesh.materials.append(mat)
    parts.append(obj)
    return obj


# Ground level is Z=0. The character looks toward Blender -Y.
# GLB/Godot conversion makes this face the game's +Z direction.
# Boots, slim legs and gloves make the silhouette readable at game distance.
for side, label in ((-1, "L"), (1, "R")):
    x = side * 0.16
    cone(f"{label} trouser", (x, 0.025, 0.60), 0.105, 0.12, 0.74, black_light)
    cube(f"{label} boot", (x, -0.08, 0.14), (0.23, 0.38, 0.28), black, 0.025)
    cube(f"{label} boot top", (x, 0.01, 0.31), (0.24, 0.24, 0.10), black)
    segment(f"{label} arm", (side * 0.35, 0.0, 1.53), (side * 0.43, -0.06, 1.03), 0.115, black)
    ico(f"{label} glove", (side * 0.43, -0.07, 0.97), 0.11, ivory, scale=(0.8, 0.75, 1.05))
    cube(f"{label} cuff", (side * 0.43, -0.04, 1.08), (0.22, 0.23, 0.075), ivory)
    cube(f"{label} brass cuff stud", (side * 0.43, -0.166, 1.08), (0.045, 0.015, 0.045), gold)

# A structured long coat, cut open in front, with two distinct tails.
cone("tailored coat body", (0, 0.08, 1.20), 0.41, 0.29, 0.95, black, 8)
cone("ivory waistcoat", (0, -0.225, 1.31), 0.235, 0.19, 0.48, ivory, 6)
cube("left coat lapel", (-0.145, -0.29, 1.51), (0.105, 0.055, 0.31), black_light)
cube("right coat lapel", (0.145, -0.29, 1.51), (0.105, 0.055, 0.31), black_light)
cube("dark neck scarf", (0, -0.29, 1.65), (0.15, 0.055, 0.22), red)
for z in (1.39, 1.24, 1.09):
    ico(f"waistcoat brass button {z}", (0, -0.373, z), 0.027, gold)

for side, label in ((-1, "L"), (1, "R")):
    x1, x2 = side * 0.06, side * 0.35
    polygon(
        f"{label} split coat tail",
        [(x1, 0.20, 0.88), (x2, 0.22, 0.88),
         (side * 0.43, 0.29, 0.28), (side * 0.045, 0.26, 0.35),
         (x1, 0.265, 0.88), (x2, 0.285, 0.88),
         (side * 0.43, 0.35, 0.28), (side * 0.045, 0.32, 0.35)],
        [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
         (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)],
        black,
    )
    segment(f"{label} pale tail piping", (side * 0.43, 0.32, 0.30),
            (side * 0.35, 0.25, 0.87), 0.012, ivory, 5)

# Faceted face, one visible eye and an asymmetrical blank porcelain half-mask.
cone("high collar", (0, 0.08, 1.74), 0.225, 0.20, 0.16, black_light)
ico("unmasked face", (0, -0.005, 1.94), 0.245, skin, 2, (0.9, 0.78, 1.13))
polygon(
    "single-piece porcelain half mask",
    [(-0.22, -0.14, 2.13), (0.005, -0.22, 2.14),
     (0.035, -0.26, 1.94), (0.0, -0.205, 1.78),
     (-0.19, -0.13, 1.80), (-0.29, -0.035, 1.98)],
    [(0, 5, 4, 3, 2, 1)], bone,
)
ico("right amber eye", (0.105, -0.183, 1.995), 0.025, eye, 1)
segment("mask seam", (0.006, -0.235, 2.13), (0.0, -0.228, 1.80), 0.008, gold, 5)

# A stage-master hat with a low, angular crown and a conspicuous pale band.
cone("hat brim", (0, 0.035, 2.195), 0.34, 0.34, 0.052, black, 12)
cone("hat crown", (0, 0.045, 2.38), 0.21, 0.19, 0.36, black, 8)
cone("ivory hat band", (0, 0.045, 2.245), 0.216, 0.211, 0.055, ivory, 8)
ico("red hat pin", (0.19, -0.07, 2.27), 0.035, red)

# The silent bell echoes one accessory on the protagonist without exposing the twist.
segment("bell chain", (-0.275, -0.285, 1.39), (-0.31, -0.32, 1.15), 0.009, gold, 5)
cone("single silent bell", (-0.31, -0.32, 1.12), 0.052, 0.026, 0.085, gold, 8)
cube("bell dark opening", (-0.31, -0.32, 1.071), (0.055, 0.055, 0.012), black)

# Presentation objects live outside the exported character collection.
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.015))
ground = bpy.context.object
ground.name = "Preview floor | not exported"
for collection in list(ground.users_collection):
    collection.objects.unlink(ground)
preview.objects.link(ground)
ground.data.materials.append(material("Preview floor", (0.065, 0.066, 0.085)))


def light(name, location, power, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    preview.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, 1.25)) - obj.location).to_track_quat("-Z", "Y").to_euler()


light("large warm key", (3, -4, 5), 600, 4, (1.0, 0.86, 0.70))
light("cool edge", (-3, 2, 3), 650, 3, (0.57, 0.65, 1.0))
cam_data = bpy.data.cameras.new("Portrait camera")
cam = bpy.data.objects.new("Portrait camera", cam_data)
preview.objects.link(cam)
cam.location = (3.6, -6.2, 2.7)
cam.rotation_euler = (Vector((0, 0, 1.25)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam_data.type = "ORTHO"
cam_data.ortho_scale = 3.25
bpy.context.scene.camera = cam

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 800
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / "contrarregra_preview.png")
scene.world.color = (0.08, 0.08, 0.10)
scene.view_settings.view_transform = "AgX"

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "contrarregra.blend"))
for obj in bpy.context.selected_objects:
    obj.select_set(False)
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "contrarregra.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
)
bpy.ops.render.render(write_still=True)
print(f"Created {len(parts)} character parts in {OUT}")
