extends RefCounted
# Fuel/embers measured in WORLD seconds, actions in real unpaused seconds.
const MATCH_CHANCE := 0.85
const SPARK_CHANCE := 0.25
const FUEL_SECONDS = {"birch":1800.0,"spruce":2160.0,"beech":3000.0,"oak":3600.0}
static func create(id: String, pos: Vector3) -> Dictionary:
 return {"id":id,"pos":[pos.x,pos.y,pos.z],"state":"unlit","fuel":0.0,"embers":0.0,"tinder":4,"weather_exposure":0.0}
static func chance(method: String, wet: float, rain: bool, intensity:float=1.0, wind:float=0.0) -> float:
 var base: float = MATCH_CHANCE if method=="match" else SPARK_CHANCE
 return clampf(base-wet*0.002-(0.15*clampf(intensity,0,1) if rain else 0.0)-0.12*clampf(wind,0,1),0.05,0.95)
static func advance(f: Dictionary, seconds: float, rain: bool, intensity:float=1.0, wind:float=0.0) -> void:
 if f["state"]=="burning":
  var rate := 1.0+0.5*clampf(intensity,0,1) if rain else 1.0
  rate += 0.3*clampf(wind,0,1)
  var used := minf(seconds,float(f["fuel"])/rate)
  f["fuel"]=maxf(0,float(f["fuel"])-seconds*rate)
  if f["fuel"]<=0:
   f["state"]="embers";f["embers"]=maxf(0,600.0-(seconds-used))
 elif f["state"]=="embers":f["embers"]=maxf(0,float(f["embers"])-seconds)
 if f["state"]=="embers" and f["embers"]<=0:f["state"]="cold"
static func time_to_change(f:Dictionary,rain:float,wind:float=0.0) -> float:
 if f["state"]=="burning":return maxf(0,float(f.get("fuel",0)))/(1.0+0.5*clampf(rain,0,1)+0.3*clampf(wind,0,1))
 if f["state"]=="embers":return maxf(0,float(f.get("embers",0)))
 return 0.0
static func add_fuel(f: Dictionary, seconds: float) -> void:
 f["fuel"]+=seconds
 if f["state"]=="embers" and f["embers"]>0:f["state"]="burning";f["embers"]=0.0
