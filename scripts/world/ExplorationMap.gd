extends RefCounted
# Forest coordinates: X east, -Z north. Spec coordinates are X east, Y north.
const WORLD_SIZE:=4000.0
const MIN_WORLD:=-2000.0
const GRID:=100
const CELL:=WORLD_SIZE/GRID
const REVEAL_RADIUS:=90.0
const MARKER_KINDS:=["camp","food","water","danger","supplies","route"]
var explored:Dictionary={}
var discovered:Dictionary={}
var markers:Array=[]
var next_id:=1
var revision:=0
var last_position:=Vector2(INF,INF)
var spec:Dictionary={}
var landmarks:Array=[]
var atlas:ImageTexture
var fog:ImageTexture
var _fog_revision:=-1
func _init()->void:
 spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/spec.json"))
 for poi in spec.get("pois",[]):
  landmarks.append({"id":str(poi.id),"name":str(poi.name),"xz":[float(poi.position[0]),-float(poi.position[1])]})
 landmarks.append({"id":"FIRST_NIGHT_CABIN","name":"Лесная стоянка","xz":[-914.0,1086.0]})
func in_bounds(point:Vector2)->bool:
 return point.is_finite() and point.x>=MIN_WORLD and point.x<=2000 and point.y>=MIN_WORLD and point.y<=2000
func cell_at(point:Vector2)->Vector2i:
 return Vector2i(clampi(floori((point.x-MIN_WORLD)/CELL),0,GRID-1),clampi(floori((point.y-MIN_WORLD)/CELL),0,GRID-1))
func key(cell:Vector2i)->String:return "%d:%d" % [cell.x,cell.y]
func is_revealed(point:Vector2)->bool:return in_bounds(point) and explored.has(key(cell_at(point)))
func _reveal(point:Vector2)->void:
 var c:=cell_at(point);var radius:=ceili(REVEAL_RADIUS/CELL)
 for x in range(maxi(0,c.x-radius),mini(GRID,c.x+radius+1)):
  for y in range(maxi(0,c.y-radius),mini(GRID,c.y+radius+1)):
   var center:=Vector2(MIN_WORLD+(x+0.5)*CELL,MIN_WORLD+(y+0.5)*CELL)
   if center.distance_to(point)>REVEAL_RADIUS:continue
   explored[key(Vector2i(x,y))]=true
func explore(point:Vector2)->bool:
 if not in_bounds(point):return false
 if last_position.is_finite() and last_position.distance_to(point)<12:return false
 var before:=explored.size();var before_poi:=discovered.size()
 if last_position.is_finite() and last_position.distance_to(point)<=250:
  var steps:=maxi(1,ceili(last_position.distance_to(point)/20.0))
  for i in range(1,steps+1):_reveal(last_position.lerp(point,float(i)/steps))
 else:_reveal(point) # Teleports never paint an unexplored corridor across the map.
 last_position=point
 for poi in landmarks:
  var at:=Vector2(float(poi.xz[0]),float(poi.xz[1]))
  if point.distance_to(at)<=REVEAL_RADIUS:discovered[str(poi.id)]=true
 if explored.size()!=before or discovered.size()!=before_poi:revision+=1;return true
 return false
func coverage()->float:return 100.0*explored.size()/float(GRID*GRID)
func add_marker(point:Vector2,text:String,kind:String)->int:
 if not is_revealed(point) or markers.size()>=256 or kind not in MARKER_KINDS:return -1
 var id:=next_id;next_id+=1
 markers.append({"id":id,"xz":[point.x,point.y],"text":text.strip_edges().left(60),"kind":kind});revision+=1;return id
func update_marker(id:int,text:String,kind:String)->bool:
 if kind not in MARKER_KINDS:return false
 for marker in markers:
  if int(marker.id)==id:marker.text=text.strip_edges().left(60);marker.kind=kind;revision+=1;return true
 return false
func remove_marker(id:int)->bool:
 for i in markers.size():
  if int(markers[i].id)==id:markers.remove_at(i);revision+=1;return true
 return false
func export_state()->Dictionary:
 return {"version":1,"explored":explored.keys(),"discovered":discovered.keys(),"markers":markers.duplicate(true),"next_id":next_id,"last_position":[last_position.x,last_position.y] if last_position.is_finite() else []}
func import_state(state:Dictionary)->void:
 explored.clear();discovered.clear();markers.clear();last_position=Vector2(INF,INF);next_id=1
 for id in state.get("explored",[]):
  var parts:=str(id).split(":")
  if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():continue
  var c:=Vector2i(int(parts[0]),int(parts[1]))
  if c.x>=0 and c.x<GRID and c.y>=0 and c.y<GRID:explored[key(c)]=true
 for id in state.get("discovered",[]):
  for poi in landmarks:
   if str(id)==str(poi.id):discovered[str(id)]=true;break
 var ids:Dictionary={}
 for marker in state.get("markers",[]):
  if markers.size()>=256:break
  if not marker is Dictionary or not marker.get("xz") is Array or marker.xz.size()!=2:continue
  var point:=Vector2(float(marker.xz[0]),float(marker.xz[1]));var id:=int(marker.get("id",0));var kind:=str(marker.get("kind",""))
  if id<1 or ids.has(id) or not is_revealed(point) or kind not in MARKER_KINDS:continue
  ids[id]=true;markers.append({"id":id,"xz":[point.x,point.y],"text":str(marker.get("text","")).left(60),"kind":kind});next_id=maxi(next_id,id+1)
 var pos=state.get("last_position",[])
 if pos is Array and pos.size()==2:
  var point:=Vector2(float(pos[0]),float(pos[1]))
  if in_bounds(point):last_position=point
 revision+=1
func fog_texture()->ImageTexture:
 if fog!=null and _fog_revision==revision:return fog
 var image:=Image.create(GRID,GRID,false,Image.FORMAT_RGBA8);image.fill(Color("202b29"))
 for id in explored:
  var parts:=str(id).split(":");image.set_pixel(int(parts[0]),int(parts[1]),Color(0,0,0,0))
 if fog==null:fog=ImageTexture.create_from_image(image)
 else:fog.update(image)
 _fog_revision=revision;return fog
func atlas_texture()->ImageTexture:
 if atlas!=null:return atlas
 var raw:=FileAccess.get_file_as_bytes("res://data/heightmap_4096_v2.r16")
 var image:=Image.create(512,512,false,Image.FORMAT_RGB8)
 var valid:=raw.size()==4096*4096*2
 for y in 512:
  for x in 512:
   var height:=height_sample(raw,x,y) if valid else 0.0
   var right:=height_sample(raw,mini(511,x+1),y) if valid else 0.0
   var below:=height_sample(raw,x,mini(511,y+1)) if valid else 0.0
   var shade:=clampf(1.0+(height-right)*0.025+(height-below)*0.035,0.65,1.15)
   var color:=Color("b9c3a1").lerp(Color("e1d1ab"),clampf(height/280.0,0,1))
   if height>250:color=color.lerp(Color("dedbd0"),clampf((height-250)/150.0,0,1))
   if floori(height/20.0)!=floori(right/20.0) or floori(height/20.0)!=floori(below/20.0):color=color.darkened(0.18)
   image.set_pixel(x,y,Color(color.r*shade,color.g*shade,color.b*shade))
 atlas=ImageTexture.create_from_image(image);return atlas
func height_sample(raw:PackedByteArray,x:int,y:int)->float:
 var index:=(y*8*4096+x*8)*2
 return float(int(raw[index])|(int(raw[index+1])<<8))*400.0/65535.0
