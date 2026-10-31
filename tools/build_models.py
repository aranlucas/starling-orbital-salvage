"""Build Starling's original Blender models, export GLBs, and render 2D sprites.

Run from any directory:
  blender --background --factory-startup --python tools/build_models.py

Godot consumes the PNGs, so Blender is only needed when editing/rebuilding art.
"""

import math
from pathlib import Path
import random

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art"
MODELS = ROOT / "assets" / "models"
ART.mkdir(parents=True, exist_ok=True)
MODELS.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, color, metallic=0.0, roughness=0.4, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1)
    return mat


ivory = material("Ceramic ivory hull", (0.76, 0.81, 0.75), 0.5)
graphite = material("Graphite titanium", (0.065, 0.10, 0.13), 0.7)
orange = material("Rescue orange panels", (0.90, 0.32, 0.055), 0.5)
teal = material("Mint glass canopy", (0.08, 0.68, 0.57), 0.65, 0.22, 0.35)
engine = material("Warm ion exhaust", (1.0, 0.48, 0.07), 0.2, 0.25, 3)
gold = material("Energy core crystal", (1.0, 0.40, 0.03), 0.55, 0.25, 0.25)


def finish(obj, name, mat, parent=None, bevel=0.0):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    if bevel:
        modifier = obj.modifiers.new("Manufactured edge bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def cube(name, location, scale, mat, parent, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def extrude(name, points, low, high, mat, parent):
    count = len(points)
    vertices = [(x, y, low) for x, y in points] + [(x, y, high) for x, y in points]
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces.extend((i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, 0.045)


def root(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    return obj


ship = root("Starling salvage ship")
hull = [(0, 2), (0.47, 1.2), (0.62, -1.45), (0.40, -1.8), (-0.40, -1.8), (-0.62, -1.45), (-0.47, 1.2)]
extrude("Armored lower chassis", hull, -0.22, 0.12, graphite, ship)
extrude("Ivory upper fuselage", [(x * 0.9, y * 0.97) for x, y in hull], 0.12, 0.40, ivory, ship)
for side in [-1, 1]:
    wing = [(side * 0.45, 0.5), (side * 1.35, -0.45), (side * 1.3, -1.55), (side * 0.48, -1.25)]
    if side < 0:
        wing.reverse()
    extrude("Port stabilizer" if side < 0 else "Starboard stabilizer", wing, -0.1, 0.12, ivory, ship)
    cube("Orange wing panel", (side * 0.91, -0.85, 0.17), (0.43, 0.4, 0.09), orange, ship)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.27, depth=1.6, location=(side * 0.95, -0.95, 0.14), rotation=(math.pi / 2, 0, 0))
    finish(bpy.context.object, "Ion engine housing", graphite, ship, 0.045)
    cube("Engine ceramic cover", (side * 0.95, -0.73, 0.35), (0.43, 0.87, 0.2), ivory, ship)
    cube("Engine orange band", (side * 0.95, -1.05, 0.48), (0.46, 0.12, 0.04), orange, ship, 0.01)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.19, depth=0.07, location=(side * 0.95, -1.78, 0.14), rotation=(math.pi / 2, 0, 0))
    finish(bpy.context.object, "Glowing engine nozzle", engine, ship)
    cube("Mint navigation light", (side * 1.26, -0.52, 0.21), (0.09, 0.22, 0.06), teal, ship, 0.02)
cube("Cockpit gasket", (0, 0.62, 0.44), (0.76, 1.30, 0.10), graphite, ship, 0.15)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(0, 0.66, 0.49))
canopy = bpy.context.object
canopy.scale = (0.32, 0.59, 0.23)
finish(canopy, "Faceted mint cockpit", teal, ship)
cube("Canopy spine", (0, 0.7, 0.72), (0.045, 1.05, 0.035), ivory, ship, 0.01)
cube("Rear orange service panel", (0, -1.27, 0.44), (0.62, 0.3, 0.08), orange, ship)
cube("Cargo pack", (0, -0.55, 0.51), (0.54, 0.58, 0.17), graphite, ship)
for y in [-0.7, -0.52, -0.34]:
    cube("Cargo strap", (0, y, 0.61), (0.46, 0.035, 0.03), ivory, ship, 0.005)

asteroid = root("Faceted iron asteroid")
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.45)
rock = bpy.context.object
rock_rng = random.Random(17)
for vertex in rock.data.vertices:
    vertex.co *= rock_rng.uniform(0.85, 1.15)
    vertex.co.z *= 0.8
rock_mats = [material("Iron rock facet %d" % i, (0.19 + i * 0.018, 0.17 + i * 0.014, 0.19 + i * 0.016), 0.25, 0.85) for i in range(5)]
finish(rock, "Irregular low-poly rock", rock_mats[0], asteroid)
for mat in rock_mats[1:]:
    rock.data.materials.append(mat)
for face in rock.data.polygons:
    face.material_index = rock_rng.randrange(5)
for i, (x, y, z) in enumerate([(0.35, 0.4, 1.06), (-0.5, -0.1, 1.0), (0.6, -0.6, 0.9)]):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.14, location=(x, y, z))
    vein = bpy.context.object
    vein.scale = (1.7, 0.45, 0.35)
    vein.rotation_euler.z = i * 0.9
    finish(vein, "Copper mineral seam", orange, asteroid)

core = root("Salvage energy core")
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.66, depth=1.5, rotation=(math.pi / 2, 0, 0))
finish(bpy.context.object, "Hexagonal amber crystal", gold, core, 0.06)
for y in [-0.77, 0.77]:
    cube("Core graphite end cap", (0, y, 0), (1.2, 0.22, 1.2), graphite, core)
    cube("Core mint charge indicator", (0, y, 0.63), (0.55, 0.07, 0.04), teal, core, 0.01)
for x in [-0.55, 0.55]:
    cube("Core retaining rail", (x, 0, 0.59), (0.10, 1.34, 0.10), ivory, core, 0.02)

drone = root("Relay sentry drone")
red = material("Sentry vermilion armor", (0.72, 0.13, 0.07), 0.6)
eye = material("Sentry amber optic", (1.0, 0.23, 0.035), 0.3, 0.25, 2)
extrude("Sentry diamond chassis", [(0, 1.4), (0.85, 0.25), (0.65, -0.85), (0, -1.1), (-0.65, -0.85), (-0.85, 0.25)], -0.18, 0.18, graphite, drone)
for side in [-1, 1]:
    cube("Sentry armored outrigger", (side * 0.85, -0.1, 0.10), (0.4, 1.35, 0.4), red, drone, 0.10)
    cube("Sentry stabilizer", (side * 0.9, -0.85, 0.05), (0.5, 0.3, 0.25), graphite, drone)
    cube("Sentry glowing thruster", (side * 0.85, -0.9, 0.05), (0.22, 0.08, 0.18), eye, drone)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(0, 0.35, 0.24))
optic = bpy.context.object
optic.scale = (0.33, 0.43, 0.18)
finish(optic, "Sentry single glowing optic", eye, drone)
cube("Sentry central armor", (0, -0.45, 0.27), (0.7, 0.65, 0.17), red, drone)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.world.use_nodes = True
background = next(node for node in scene.world.node_tree.nodes if node.type == "BACKGROUND")
background.inputs[0].default_value = (0.17, 0.25, 0.32, 1)
background.inputs[1].default_value = 0.45
scene.view_settings.view_transform = "AgX"


def light(name, location, color, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()


light("Warm key softbox", (-3, 4, 7), (1, 0.86, 0.67), 800, 4)
light("Mint rim softbox", (4, -1, 5), (0.45, 1, 0.87), 950, 3)
camera_data = bpy.data.cameras.new("Orthographic sprite camera")
camera = bpy.data.objects.new("Orthographic sprite camera", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (0, 0, 12)
camera_data.type = "ORTHO"
scene.camera = camera
camera.rotation_euler = (0, 0, 0)

assets = [(ship, "ship", 5.0), (asteroid, "asteroid", 3.8), (core, "energy_core", 2.6), (drone, "drone", 3.5)]
for target, name, ortho_scale in assets:
    bpy.ops.object.select_all(action="DESELECT")
    for model, _, _ in assets:
        for obj in [model, *model.children_recursive]:
            obj.hide_render = model != target
            obj.select_set(model == target)
    camera_data.ortho_scale = ortho_scale
    bpy.ops.export_scene.gltf(filepath=str(MODELS / (name + ".glb")), use_selection=True, export_apply=True)
    scene.render.filepath = str(ART / (name + ".png"))
    bpy.ops.render.render(write_still=True)

# Save an editable library with all assets laid out side by side.
for i, (model, _, _) in enumerate(assets):
    model.location.x = (i - 1.5) * 4.5
    for obj in [model, *model.children_recursive]:
        obj.hide_render = False
        obj.select_set(True)
camera.location = (0, 0, 16)
camera_data.ortho_scale = 20
scene.render.resolution_x = 1600
scene.render.resolution_y = 600
scene.render.filepath = str(ART / "model_lineup.png")
bpy.ops.wm.save_as_mainfile(filepath=str(MODELS / "starling_assets.blend"))
bpy.ops.render.render(write_still=True)
print("STARLING: exported 4 GLB models, 4 transparent sprites, and editable Blender source.")
