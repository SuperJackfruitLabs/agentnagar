## Optional runtime animation for the original Codex tiered fountain.
## Add with FountainFlow.attach(fountain_instance). No changes to the GLB needed.
## All coordinates are local metres, so existing placement scale is respected.
extends Node3D
class_name FountainFlow

const WATER_SHADER = preload("water_flow.gdshader")
const LOOP_SECONDS := 4.0
var playing := true
var clock := 0.0
var _materials: Array[ShaderMaterial] = []
var _splash: MultiMeshInstance3D
var _impacts: Array[Vector3] = []

static func supports(fountain: Node3D) -> bool:
 var water := fountain.find_child("water", true, false) as MeshInstance3D
 if water == null or water.mesh == null:
  return false
 for surface in water.mesh.get_surface_count():
  var material := water.get_active_material(surface)
  if material != null and material.resource_name.begins_with("Turquoise drawn water"):
   return true
 return false

static func attach(fountain: Node3D) -> FountainFlow:
 var old := fountain.get_node_or_null("FountainFlow")
 if old != null:
  return old as FountainFlow
 var flow := FountainFlow.new()
 flow.name = "FountainFlow"
 fountain.add_child(flow)
 flow._setup(fountain)
 return flow

func _setup(fountain: Node3D) -> void:
 var water := fountain.find_child("water", true, false) as MeshInstance3D
 if water == null or water.mesh == null:
  push_error("FountainFlow requires the fountain GLB's named water mesh")
  return
 for surface in water.mesh.get_surface_count():
  var original := water.get_active_material(surface) as BaseMaterial3D
  var material := ShaderMaterial.new()
  material.shader = WATER_SHADER
  if original != null:
   material.set_shader_parameter("water_color", original.albedo_color)
   material.set_shader_parameter("foam_strength", 0.2 if original.resource_name.contains("Pale") else 0.5)
  water.set_surface_override_material(surface, material)
  _materials.append(material)
 for k in 4:
  var angle := k * PI / 2.0
  _impacts.append(Vector3(0.47*cos(angle), 1.12, -0.47*sin(angle)))
  angle += PI/4.0
  _impacts.append(Vector3(0.94*cos(angle), 0.333, -0.94*sin(angle)))
 var shape := _droplet_mesh()
 var material := StandardMaterial3D.new()
 material.albedo_color = Color("bce5e5")
 material.roughness = 0.32
 shape.surface_set_material(0, material)
 _splash = MultiMeshInstance3D.new()
 _splash.name = "Small landing splashes"
 _splash.multimesh = MultiMesh.new()
 _splash.multimesh.transform_format = MultiMesh.TRANSFORM_3D
 _splash.multimesh.mesh = shape
 _splash.multimesh.instance_count = _impacts.size()*5
 # All splash arcs stay inside the stone basin and outside sitting surfaces.
 _splash.custom_aabb = AABB(Vector3(-1.2,0.3,-1.2),Vector3(2.4,1.1,2.4))
 add_child(_splash)
 set_time(0.0)

func _process(delta: float) -> void:
 if playing:
  set_time(clock+delta)

func set_time(seconds: float) -> void:
 clock = fposmod(seconds, LOOP_SECONDS)
 for material in _materials:
  material.set_shader_parameter("flow_time", clock)
 if _splash == null:
  return
 var transforms: Array[Transform3D] = []
 for i in _impacts.size():
  for j in 5:
   var u := fposmod(clock*2.0 + float(j)/5.0 + float(i)*0.173,1.0)
   var angle := float(j)*TAU/5.0 + float(i)*0.57
   var height := 0.09 + 0.022*sin(float(i+j)*1.7)
   var pos := _impacts[i]+Vector3(cos(angle)*0.09*u, 4.0*height*u*(1.0-u), sin(angle)*0.09*u)
   var size := 0.012*sin(PI*u)
   var basis := Basis.IDENTITY.scaled(Vector3(size, size*1.7, size))
   var transform := Transform3D(basis,pos)
   _splash.multimesh.set_instance_transform(i*5+j,transform)
   transforms.append(transform)
 if DisplayServer.get_name() == "headless":
  # The game audit reads these when the dummy renderer stores no transforms.
  _splash.set_meta("instance_xforms",transforms)

static func _droplet_mesh() -> ArrayMesh:
 var v := PackedVector3Array([Vector3(0,1,0),Vector3(1,0,0),Vector3(0,0,1),Vector3(-1,0,0),Vector3(0,0,-1),Vector3(0,-1,0)])
 var triangles := [[0,2,1],[0,3,2],[0,4,3],[0,1,4],[5,1,2],[5,2,3],[5,3,4],[5,4,1]]
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for tri in triangles:
  for index in tri:
   st.add_vertex(v[index])
 st.generate_normals()
 return st.commit()
