"""Build the Deep Orbit model library, GLBs and renders.

Run: blender --background --factory-startup --python tools/build_deep_orbit_models.py
"""
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets' / 'art'
MODELS = ROOT / 'assets' / 'models'
ART.mkdir(parents=True, exist_ok=True)
MODELS.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
rng = random.Random(1031)


def material(name, color, metallic=0.0, roughness=0.4, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = next(node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    if emission:
        shader.inputs['Emission Color'].default_value = (*color, 1)
        shader.inputs['Emission Strength'].default_value = emission
    mat.diffuse_color = (*color, 1)
    return mat


ivory = material('Ceramic ivory hull', (0.76, 0.81, 0.75), 0.5)
graphite = material('Graphite titanium', (0.065, 0.10, 0.13), 0.7)
orange = material('Rescue orange panels', (0.90, 0.32, 0.055), 0.5)
teal = material('Mint glass canopy', (0.08, 0.68, 0.57), 0.65, 0.22, 0.35)
mint = material('Mint beacon', (0.12, 0.85, 0.68), 0.25, 0.25, 2.5)
engine = material('Warm ion exhaust', (1.0, 0.48, 0.07), 0.2, 0.25, 3)
violet = material('Accretion violet', (0.35, 0.13, 0.55), 0.3, 0.3, 1.7)
rock_mats = [material('Iron rock facet %d' % i, (0.19+i*0.018, 0.17+i*0.014, 0.19+i*0.016), 0.25, 0.85) for i in range(5)]
dark = material('Collapsed core', (0.012, 0.018, 0.028), 0.3, 0.6)


def root(name, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return obj


def finish(obj, name, mat, parent=None, bevel=0.0):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    if bevel:
        modifier = obj.modifiers.new('Manufactured edge bevel', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    return obj


def cube(name, location, scale, mat, parent, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def extrude(name, points, low, high, mat, parent):
    n = len(points)
    vertices = [(x, y, low) for x, y in points] + [(x, y, high) for x, y in points]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces.extend((i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, 0.035)


def cylinder(name, loc, radius, depth, mat, parent, axis='Z', vertices=16):
    rot = (math.pi/2, 0, 0) if axis == 'Y' else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.object, name, mat, parent, 0.025)


def torus(name, loc, major, minor, mat, parent):
    bpy.ops.mesh.primitive_torus_add(major_segments=64, minor_segments=8, location=loc, major_radius=major, minor_radius=minor)
    return finish(bpy.context.object, name, mat, parent)


def sphere(name, loc, scale, mat, parent, sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, parent)


def beam(name, a, b, width, mat, parent):
    mid = (Vector(a) + Vector(b)) / 2
    obj = cube(name, mid, (width, width, (Vector(b)-Vector(a)).length), mat, parent, width*0.15)
    obj.rotation_euler = (Vector(b)-Vector(a)).to_track_quat('Z', 'Y').to_euler()
    return obj


def rocky(name, loc, scale, parent, seed):
    local = random.Random(seed)
    obj = sphere(name, loc, scale, rock_mats[0], parent)
    for v in obj.data.vertices:
        v.co *= local.uniform(0.82, 1.16)
    for mat in rock_mats[1:]:
        obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.material_index = local.randrange(len(rock_mats))
    return obj


assets = []
def asset(name):
    obj = root(name)
    assets.append((obj, name))
    return obj


k = asset('kestrel')
extrude('Spear lower chassis', [(0,1.95),(.42,1.0),(.48,-1.45),(.30,-1.8),(-.30,-1.8),(-.48,-1.45),(-.42,1.0)], -.18,.12,graphite,k)
extrude('Ivory spear hull', [(0,1.9),(.38,.92),(.39,-1.32),(0,-1.52),(-.39,-1.32),(-.38,.92)], .12,.38,ivory,k)
for side in (-1, 1):
    points = [(side*.36,.65),(side*1.35,-.92),(side*1.24,-1.45),(side*.38,-1.06)]
    if side < 0: points.reverse()
    extrude('Swept wing', points, -.08,.12,ivory,k)
    cube('Orange wing marking',(side*.85,-.88,.15),(.38,.34,.06),orange,k)
    cube('Wingtip light',(side*1.2,-1.13,.16),(.08,.19,.05),mint,k,.01)
cylinder('Single engine housing',(0,-1.27,.13),.38,1.1,graphite,k,'Y')
cylinder('Single glowing nozzle',(0,-1.84,.13),.28,.05,engine,k,'Y')
sphere('Mint canopy',(0,.58,.41),(.28,.58,.20),teal,k)
cube('Dorsal orange stripe',(0,-.73,.41),(.22,.5,.06),orange,k)

a = asset('albatross')
extrude('Broad hauler chassis', [(-1.7,-1.8),(1.7,-1.8),(1.9,.4),(.85,1.65),(0,2.45),(-.85,1.65),(-1.9,.4)], -.28,.15,graphite,a)
extrude('Ceramic bridge armor',[(-.8,-1.4),(.8,-1.4),(1.0,.6),(0,2.35),(-1.0,.6)],.15,.48,ivory,a)
sphere('Bridge canopy',(0,1.05,.5),(.42,.62,.22),teal,a)
for side in (-1,1):
    cube('Cargo pod',(side*1.45,-.15,.42),(.74,2.25,.65),ivory,a,.12)
    for y in (-.85,.55): cube('Cargo restraint',(side*1.45,y,.78),(.78,.13,.08),orange,a,.015)
    for x in (.85,1.65):
        cylinder('Hauler engine',(side*x,-1.65,.0),.28,1.0,graphite,a,'Y')
        cylinder('Hauler exhaust',(side*x,-2.17,0),.20,.06,engine,a,'Y')

s = asset('salvage_wing')
extrude('Drone chassis',[(0,.42),(.23,.13),(.22,-.25),(0,-.38),(-.22,-.25),(-.23,.13)],-.07,.10,graphite,s)
for side in (-1,1):
    cube('Drone outrigger',(side*.29,-.05,.02),(.18,.42,.15),ivory,s,.03)
    cube('Drone orange marking',(side*.29,-.08,.11),(.16,.10,.04),orange,s,.01)
sphere('Drone optic',(0,.08,.12),(.13,.17,.08),teal,s,1)
cube('Drone thruster',(0,-.37,.02),(.18,.04,.08),engine,s,.01)

d = asset('dock_beacon')
cylinder('Dock foundation',(0,0,-.15),1.8,.3,graphite,d,vertices=32)
cylinder('Landing surface',(0,0,.03),1.58,.12,ivory,d,vertices=32)
ring = root('Ring',d)
torus('Mint landing ring',(0,0,.14),1.72,.07,mint,ring)
for angle in range(0,360,90):
    t = math.radians(angle)
    obj = cube('Landing marking',(1.2*math.cos(t),1.2*math.sin(t),.105),(.32,.10,.025),orange,d,.01)
    obj.rotation_euler.z = t

r = asset('roost_station')
torus('Core structural ring',(0,0,0),5.0,.42,graphite,r)
torus('Core ceramic rim',(0,0,.25),5.0,.19,ivory,r)
cylinder('Central hub',(0,0,0),1.6,.8,graphite,r,vertices=24)
cylinder('Hub cap',(0,0,.46),1.2,.15,ivory,r,vertices=24)
torus('Hub mint rim',(0,0,.56),.92,.05,mint,r)
for angle in range(0,360,45):
    t = math.radians(angle)
    beam('Radial spoke',(1.3*math.cos(t),1.3*math.sin(t),0),(4.8*math.cos(t),4.8*math.sin(t),0),.25,ivory,r)
    cube('Ring service block',(5*math.cos(t),5*math.sin(t),.13),(.6,.6,.35),orange,r,.07)
pad = root('Pad',r)
cube('Docking neck',(0,5.5,0),(1.5,3,.38),graphite,pad)
cylinder('Docking pad',(0,7.05,.05),2.05,.35,ivory,pad,vertices=32)
torus('Pad guide',(0,7.05,.25),1.65,.055,mint,pad)
charts = root('Module_Charts',r)
beam('Antenna mast',(-4,-4,.2),(-5.3,-5.3,2.3),.22,graphite,charts)
cylinder('Long range dish',(-5.45,-5.45,2.4),1.0,.18,ivory,charts,vertices=24)
torus('Dish rim',(-5.45,-5.45,2.52),.82,.05,orange,charts)
sphere('Dish receiver',(-5.45,-5.45,2.8),(.12,.12,.12),mint,charts,1)
for name, side in [('Module_Kestrel',-1),('Module_Albatross',1)]:
    m = root(name,r)
    cube('Hangar arm',(side*6.15,1.5,0),(3.1,1.1,.5),graphite,m)
    cube('Hangar deck',(side*7.55,1.5,.2),(1.5,2.3,.35),ivory,m)
    cube('Hangar marker',(side*7.55,1.5,.4),(.9,.2,.06),orange,m)
fab = root('Module_Fabricator',r)
cube('Fabricator rack',(3.9,-4.5,.5),(2.3,.7,1.1),graphite,fab)
cube('Fabricator face',(3.9,-4.12,.55),(2.0,.12,.8),ivory,fab)
for i in range(6): sphere('Fabricator indicator %d' % i,(3.1+i*.32,-4.02,.65),(.09,.07,.09),mint,fab,1)
plating = root('Module_Plating',r)
for angle in range(0,360,45):
    t=math.radians(angle)
    obj=cube('Armor segment',(5.5*math.cos(t),5.5*math.sin(t),-.1),(.7,2.0,.32),ivory,plating)
    obj.rotation_euler.z=t
broker=root('Module_Broker',r)
beam('Broker beacon mast',(4,-4,0),(4,-4,2.6),.25,graphite,broker)
sphere('Broker trade beacon',(4,-4,2.8),(.38,.38,.38),engine,broker)
rig=root('Module_Rig',r)
for x in (-.85,.85): cube('Launch rail',(x,8.9,.10),(.18,3.0,.25),orange,rig)

meteor=asset('meteor')
sphere('Molten interior',(0,0,0),(.71,.71,.71),engine,meteor)
# Separate dark plates leave a network of glowing fissures between them.
for i in range(18):
    z = rng.uniform(-.9,.9); angle = rng.uniform(0,math.tau); q=math.sqrt(1-z*z)
    p=Vector((q*math.cos(angle),q*math.sin(angle),z))
    obj=sphere('Scorched crust',p*.61,(.35,.30,.17),rock_mats[i%5],meteor,1)
    obj.rotation_euler=p.to_track_quat('Z','Y').to_euler()

b=asset('asteroid_b')
rocky('Elongated iron rock',(0,0,0),(.8,1.65,.72),b,22)
for i in range(3): sphere('Copper seam',(rng.uniform(-.4,.4),rng.uniform(-.9,.9),.65),(.23,.08,.06),orange,b,1)
c=asset('asteroid_c')
for i,(loc,sc) in enumerate([((0,0,0),(.85,.85,.70)),((.85,.3,.15),(.52,.65,.48)),((-.7,-.4,.1),(.55,.45,.62)),((.1,.95,.25),(.4,.6,.5))]): rocky('Shard cluster',loc,sc,c,42+i)
for x,y in [(-.5,-.5),(.5,.4)]: sphere('Copper seam',(x,y,.65),(.25,.09,.07),orange,c,1)

spire=asset('foundry_spire')
cube('Pylon base',(0,0,.4),(2.8,2.8,.8),graphite,spire,.12)
cube('Refinery shaft',(0,0,6),(1.25,1.25,10.8),graphite,spire,.1)
for z in (1.2,3.5,5.8,8.1,10.4):
    cube('Platform',(0,0,z),(2.5,2.5,.18),ivory,spire)
    for side in (-1,1): cube('Warning lamp',(side*1.18,0,z+.16),(.16,.35,.14),engine,spire,.02)
for x in (-1.05,1.05):
    for y in (-1.05,1.05):
        beam('Vertical girder',(x,y,.5),(x,y,11.3),.17,orange,spire)
    for z in (1.3,3.6,5.9,8.2): beam('Diagonal brace',(x,-1.05,z),(x,1.05,z+2.2),.12,graphite,spire)
cube('Crown',(0,0,11.55),(1.7,1.7,.8),ivory,spire)

well=asset('gravity_well')
sphere('Dark collapsed star',(0,0,0),(1.05,1.05,.65),dark,well)
ring.name='Dock_Ring'
wr=root('Well_Ring',well)
torus('Amber accretion',(0,0,0),3.35,.11,engine,wr)
torus('Violet accretion',(0,0,.08),2.85,.09,violet,wr)
torus('Outer accretion',(0,0,-.08),3.85,.08,violet,wr)
for i in range(16):
    t=i*math.tau/16
    sphere('Accretion fragment',(3.35*math.cos(t),3.35*math.sin(t),rng.uniform(-.15,.15)),(.12,.22,.07),engine if i%3 else violet,wr,1)

lev=asset('leviathan')
extrude('Massive armored keel',[(-3.3,-14),(3.3,-14),(3.8,-9),(3.6,8),(2.5,13),(0,15),(-2.5,13),(-3.6,8),(-3.8,-9)],-.9,.65,graphite,lev)
extrude('Upper ore hull',[(-3,-12),(3,-12),(3.1,8),(2.1,12),(0,14),(-2.1,12),(-3.1,8)],.65,1.35,ivory,lev)
for y in (-10,-6,-2,2,6,10):
    for side in (-1,1):
        cube('Armored cargo plate',(side*2.25,y,1.42),(1.25,3.4,.24),ivory,lev,.12)
        cube('Orange hazard plate',(side*2.25,y-1.1,1.57),(1.1,.22,.08),orange,lev)
for y in (-8,0,8):
    for side in (-1,1):
        beam('Crane upright',(side*3.1,y,1),(side*3.5,y,3.2),.22,graphite,lev)
        beam('Broken crane boom',(side*3.5,y,3.2),(side*2.5,y+1.5,4.0),.2,orange,lev)
for i,y in enumerate((-8,0,8)):
    vent=root('Vent_%d'%i,lev)
    cube('Vent frame',(0,y,1.46),(1.5,2.1,.25),graphite,vent,.08)
    cube('Vent reactor glow',(0,y,1.61),(1.15,1.7,.08),engine,vent,.03)
    for yy in (-.55,0,.55): cube('Vent grille',(0,y+yy,1.68),(1.25,.11,.08),graphite,vent,.015)
cylinder('Stern reactor',(0,-14.1,.1),1.05,.2,engine,lev,'Y',24)

scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=scene.render.resolution_y=256
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
bg.inputs[0].default_value=(.17,.25,.32,1)
bg.inputs[1].default_value=.45
scene.view_settings.view_transform='AgX'

def light(name,location,color,energy,size):
    data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.color=color; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); obj.location=location
    obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj

light('Warm key softbox',(-3,4,7),(1,.86,.67),800,4)
light('Mint rim softbox',(4,-1,5),(.45,1,.87),950,3)
cam_data=bpy.data.cameras.new('Orthographic sprite camera')
cam=bpy.data.objects.new('Orthographic sprite camera',cam_data); bpy.context.collection.objects.link(cam)
cam.location=(0,0,12); cam_data.type='ORTHO'; scene.camera=cam
for target,name in assets:
    bpy.ops.object.select_all(action='DESELECT')
    for model,_ in assets:
        for obj in [model,*model.children_recursive]:
            obj.hide_render=model != target
            obj.select_set(model == target)
    if target == d: ring.name = 'Ring'
    if target == well: wr.name = 'Ring'
    bpy.ops.export_scene.gltf(filepath=str(MODELS/(name+'.glb')),use_selection=True,export_apply=True)
    if target == d: ring.name = 'Dock_Ring'
    if target == well: wr.name = 'Well_Ring'
    if name in ('kestrel','albatross','salvage_wing'):
        cam_data.ortho_scale={'kestrel':5.0,'albatross':6.1,'salvage_wing':1.1}[name]
        scene.render.filepath=str(ART/(name+'.png'))
        bpy.ops.render.render(write_still=True)

# Arrange the editable library in rows, scaling only root transforms for the portrait.
# Individual GLBs above remain in metres and at the origin.
positions=[(-11,7),(-6,7),(-2,7),(3,7),(8,7),(-11,0),(-7,0),(-3,0),(.2,-1),(5,0),(11,0)]
scales={'roost_station':.38,'foundry_spire':.48,'gravity_well':.48,'leviathan':.28,'salvage_wing':2.6}
for (model,name),(x,y) in zip(assets,positions):
    model.location=(x,y,0); model.scale=(scales.get(name,1),)*3
    for obj in [model,*model.children_recursive]: obj.hide_render=False
cam.location=(0,-23,27); cam.rotation_euler=(Vector((0,3,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='PERSP'; cam_data.lens=40
scene.render.resolution_x=1800; scene.render.resolution_y=900
scene.render.film_transparent=False
bg.inputs[0].default_value=(.018,.032,.05,1); bg.inputs[1].default_value=.5
# Large softboxes illuminate the entire library.
light('Lineup key',(-10,-8,25),(1,.86,.7),3500,18)
light('Lineup rim',(12,12,18),(.45,1,.87),4000,16)
scene.render.filepath=str(ART/'deep_orbit_lineup.png')
bpy.ops.wm.save_as_mainfile(filepath=str(MODELS/'deep_orbit_assets.blend'))
bpy.ops.render.render(write_still=True)

# Equirectangular sky, rendered from inside an emissive procedural world.
# The direction vector supplies a quiet nebula and sparse point stars.
for model,_ in assets:
    for obj in [model,*model.children_recursive]: obj.hide_render=True
world=scene.world; nodes=world.node_tree.nodes; links=world.node_tree.links
nodes.clear(); out=nodes.new('ShaderNodeOutputWorld'); background=nodes.new('ShaderNodeBackground'); links.new(background.outputs[0],out.inputs['Surface'])
tex=nodes.new('ShaderNodeTexCoord'); sep=nodes.new('ShaderNodeSeparateXYZ'); links.new(tex.outputs['Generated'] if 'Generated' in tex.outputs else tex.outputs['Normal'],sep.inputs[0])
noise=nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=3.0; noise.inputs['Detail'].default_value=3
links.new(tex.outputs['Normal'],noise.inputs['Vector'])
ramp=nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.22; ramp.color_ramp.elements[0].color=(.002,.004,.015,1); ramp.color_ramp.elements[1].position=.8; ramp.color_ramp.elements[1].color=(.015,.045,.052,1)
ramp.color_ramp.elements.new(.58).color=(.025,.024,.021,1)
links.new(noise.outputs['Fac'],ramp.inputs[0])
vor=nodes.new('ShaderNodeTexVoronoi'); vor.inputs['Scale'].default_value=170; links.new(tex.outputs['Normal'],vor.inputs['Vector'])
stars=nodes.new('ShaderNodeValToRGB'); stars.color_ramp.elements[0].position=.025; stars.color_ramp.elements[0].color=(.5,.45,.34,1); stars.color_ramp.elements[1].position=.07; stars.color_ramp.elements[1].color=(0,0,0,1); links.new(vor.outputs['Distance'],stars.inputs[0])
add=nodes.new('ShaderNodeMixRGB'); add.blend_type='ADD'; add.inputs[0].default_value=1; links.new(ramp.outputs[0],add.inputs[1]); links.new(stars.outputs[0],add.inputs[2]); links.new(add.outputs[0],background.inputs[0]); background.inputs[1].default_value=1
# A distant subdued planet is actual geometry, so its curved limb is visible low in the panorama.
planetmat=material('Distant pale planet',(.11,.17,.19),0,.9,.25)
sphere('Distant planet',(0,40,-180),(125,125,125),planetmat,None,4)
cam.location=(0,0,0); cam.rotation_euler=(math.pi/2,0,0); cam_data.type='PANO'; cam_data.panorama_type='EQUIRECTANGULAR'
scene.render.resolution_x=4096; scene.render.resolution_y=2048; scene.cycles.samples=8
scene.render.filepath=str(ART/'deep_orbit_sky.png'); bpy.ops.render.render(write_still=True)
print('STARLING: exported %d Deep Orbit GLBs, four renders, sky and editable library.' % len(assets))
