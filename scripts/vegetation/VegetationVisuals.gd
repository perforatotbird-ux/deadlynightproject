extends RefCounted
# Authored fungal meshes and procedural berries, shared by near and far MultiMesh.
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
static var cache:Dictionary={}
static var material:StandardMaterial3D
static func group_position(id:String,index:int) -> Vector3:
 if Catalog.species(id).family!="berry":return Vector3(0,0.15,0)
 var r:=0.36 if id=="bolotnitsa" else 0.38
 return Vector3(cos(index*2.4)*r,(0.20 if id=="bolotnitsa" else (0.70 if id=="sizovka" else 0.53))+index*0.035,sin(index*2.4)*r)
static func _add(st:SurfaceTool,mesh:Mesh,xform:Transform3D,color:Color) -> void:
 var a:=mesh.surface_get_arrays(0);var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL];var inds:PackedInt32Array=a[Mesh.ARRAY_INDEX]
 if inds.is_empty():
  for i in v.size():inds.append(i)
 for i in inds:
  st.set_color(color);st.set_normal((xform.basis.inverse().transposed()*n[i]).normalized());st.add_vertex(xform*v[i])
static func _sphere(st:SurfaceTool,pos:Vector3,size:Vector3,color:Color) -> void:
 var s:=SphereMesh.new();s.radius=0.5;s.height=1;s.radial_segments=7;s.rings=3
 _add(st,s,Transform3D(Basis.IDENTITY.scaled(size),pos),color)
static func _stem(st:SurfaceTool,a:Vector3,b:Vector3,r:float,color:Color) -> void:
 var c:=CylinderMesh.new();c.top_radius=r*0.65;c.bottom_radius=r;c.height=a.distance_to(b);c.radial_segments=7
 var up:=(b-a).normalized();var right:=up.cross(Vector3.FORWARD).normalized();var front:=right.cross(up).normalized()
 _add(st,c,Transform3D(Basis(right,up,front),(a+b)*0.5),color)
static func mesh(id:String,mask:int=0,seed_key:String="") -> ArrayMesh:
 if Catalog.species(id).family!="berry" and mask==0:
  var authored:=preload("res://scripts/survival/ResourceModels.gd").mesh(id,seed_key)
  if authored!=null:return authored
 var key:=id+":"+str(mask)
 if cache.has(key):return cache[key]
 if material==null:
  material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=0.95
 var d:Dictionary=Catalog.species(id);var color:=Color(d.color)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 if d.family=="berry":
  var count:int=d.yield
  for i in count:
   var p:=group_position(id,i)
   _stem(st,Vector3(0,0.02,0),p,0.024,Color("64563b"))
   _sphere(st,p-Vector3.UP*0.08,Vector3(0.52,0.24,0.32) if id=="bolotnitsa" else Vector3(0.40,0.35,0.28),Color("425d43"))
   if mask & (1<<i):continue
   for j in 4:
    var q:=p+Vector3(cos(j*2.4)*0.10,0.05+float(j%2)*0.035,sin(j*2.4)*0.1)
    _sphere(st,q,Vector3(0.075,0.12 if id=="sizovka" else 0.075,0.075),color)
    if id=="bolotnitsa":_sphere(st,q+Vector3.UP*0.025,Vector3(0.06,0.05,0.06),color.lightened(0.15))
 elif mask==0:
  if id in ["wood_fan","stump_fan"]:
   # Off-centre flattened tiers, no central stalk: clear shelf silhouette.
   var tea:=id=="stump_fan"
   for i in (2 if tea else 3):
    var height:=0.10+i*(0.10 if tea else 0.065)
    _sphere(st,Vector3(0,height,0.09-i*0.025),Vector3((0.44 if tea else 0.32)-i*0.04,0.05 if tea else 0.065,0.30-i*0.025 if tea else 0.25-i*0.025),color.lightened(i*0.1))
    _sphere(st,Vector3(0,height+0.015,0.10-i*0.025),Vector3((0.34 if tea else 0.23)-i*0.035,0.018,0.23-i*0.02 if tea else 0.19-i*0.02),color.darkened(0.18))
  else:
   var fat:=id=="forest_fat";var bell:=id=="pale_bell";var h:=0.25 if fat else 0.36
   _stem(st,Vector3(0,0,0),Vector3(0,h,0),0.058 if fat else 0.022,Color("d7ccb0"))
   if bell:_sphere(st,Vector3(0,0.025,0),Vector3(0.12,0.10,0.12),Color("d7ccb0"))
   if bell:
    var c:=CylinderMesh.new();c.top_radius=0.035;c.bottom_radius=0.15;c.height=0.21;c.radial_segments=9
    _add(st,c,Transform3D(Basis.IDENTITY,Vector3(0,h+0.06,0)),color)
    for i in 9:_stem(st,Vector3(0,h-0.05,0),Vector3(cos(i*TAU/9)*0.145,h-0.045,sin(i*TAU/9)*0.145),0.009,Color("494534"))
   else:_sphere(st,Vector3(0,h,0),Vector3(0.46 if fat else 0.34,0.22 if fat else 0.085,0.46 if fat else 0.34),color)
   if id=="copper_false":
    var ring:=CylinderMesh.new();ring.top_radius=0.078;ring.bottom_radius=0.078;ring.height=0.02;ring.radial_segments=9
    _add(st,ring,Transform3D(Basis.IDENTITY,Vector3(0,h*0.62,0)),Color("ddd2b3"))
 var result:=st.commit();result.surface_set_material(0,material);cache[key]=result;return result
