extends RefCounted
# Original small wildlife geometry, not billboards. Wings animate around the body.
static func insect(moth:bool)->ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var wing:=Color("d5c79e") if moth else Color("a19c73")
 for side in [-1,1]:
  var vertices=[Vector3(0,0,-.025),Vector3(side*.065,0,-.045),Vector3(side*.045,0,.025),Vector3(0,0,.018)]
  for j in [0,2,1,0,3,2]:st.set_color(wing);st.add_vertex(vertices[j])
 var body=[Vector3(-.008,.004,-.034),Vector3(.008,.004,-.034),Vector3(0,.012,.03)]
 for j in [0,1,2]:st.set_color(Color("403b2c"));st.add_vertex(body[j])
 st.generate_normals();return st.commit()
static func wing(side:int)->ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[Vector3(0,0,-.10),Vector3(side*.16,.005,-.12),Vector3(side*.38,0,.08),Vector3(side*.27,-.005,.17),Vector3(side*.11,0,.12),Vector3(0,0,.08)]
 for i in range(1,points.size()-1):
  for j in [0,i,i+1]:st.add_vertex(points[j])
 st.generate_normals();return st.commit()
