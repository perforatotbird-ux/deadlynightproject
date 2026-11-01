extends RefCounted
# A visual projection of SurvivalWorld's existing binary weather. No gameplay RNG.
var seed_value:=41873
var lunar_days:=29.53
var initial_phase:=0.46
var latitude:=42.0
var epoch:=0.0
var previous_rain:=false
var _last_sample:Dictionary={}
var rain_style:="light_rain"
var dry_style:="clear"
var from_cloud:=0.12
var from_rain:=0.0
var from_fog:=0.0008
var from_wind:=0.12
var transition_start:=-100000.0
const TRANSITION:=900.0
const PROFILES:={
 "clear":[0.12,0.0,0.0008,0.12],"broken":[0.42,0.0,0.001,0.28],
 "overcast":[0.85,0.0,0.0015,0.4],"mist":[0.28,0.0,0.004,0.08],
 "light_rain":[0.82,0.35,0.0015,0.4],"heavy_rain":[0.96,0.85,0.0022,0.7],
 "storm":[0.99,1.0,0.0025,0.95]}
func reset(clock:float,raining:bool) -> void:
 _last_sample={}
 previous_rain=raining;transition_start=clock-TRANSITION;epoch=clock
 rain_style="light_rain";dry_style="clear"
func sample(clock:float,raining:bool,until:float,day:float,season_cuts:Dictionary={}) -> Dictionary:
 if raining!=previous_rain:
  var old:Dictionary=_last_sample if not _last_sample.is_empty() else _current(clock,until,day)
  from_cloud=old.cloud;from_rain=old.rain;from_fog=old.fog;from_wind=old.wind
  previous_rain=raining;transition_start=clock;epoch=clock
  var pick:=posmod(int(clock/60.0)*73+seed_value,100)
  # Legacy thresholds when no seasonal table is given (tests and callers that
  # never heard of seasons keep the original style distribution).
  var storm_cut:=float(season_cuts.get("storm",18))
  var heavy_cut:=float(season_cuts.get("heavy",53))
  var mist_cut:=float(season_cuts.get("mist",20))
  var broken_cut:=float(season_cuts.get("broken",65))
  if raining:rain_style="storm" if pick<storm_cut else ("heavy_rain" if pick<heavy_cut else "light_rain")
  else:dry_style="mist" if pick<mist_cut else ("broken" if pick<broken_cut else "clear")
 _last_sample=_current(clock,until,day)
 return _last_sample
func _current(clock:float,until:float,day:float) -> Dictionary:
 var kind:=rain_style if previous_rain else dry_style
 var p:Array=PROFILES[kind]
 var cloud:float=p[0];var rain:float=p[1];var fog:float=p[2];var wind:float=p[3]
 if not previous_rain:
  # A 30-minute world-time cloud prelude, never an unannounced gameplay penalty.
  var prelude:=1.0-smoothstep(0,1800,maxf(0,until-clock))
  cloud=lerpf(cloud,0.86,prelude);wind=lerpf(wind,0.48,prelude)
  if prelude>0.7:kind="overcast"
 var t:=smoothstep(0,TRANSITION,clock-transition_start)
 var gust:=0.88+0.12*sin(clock*0.0027+seed_value)
 return {"kind":kind,"cloud":lerpf(from_cloud,cloud,t),"rain":lerpf(from_rain,rain,t),"fog":lerpf(from_fog,fog,t),"wind":lerpf(from_wind,wind,t)*gust,"storm":float(previous_rain and rain_style=="storm")*t,"day":day,"wind_direction":Vector3(0.8,0,0.6)}
func celestial(clock:float) -> Dictionary:
 var theta:=fposmod(clock,86400.0)/86400.0*TAU-PI
 var lat:=deg_to_rad(latitude)
 var meridian:=Vector3(0,cos(lat),sin(lat));var pole:=Vector3(0,sin(lat),-cos(lat))
 var elongation:=fposmod(initial_phase+clock/(86400.0*lunar_days),1.0)*TAU
 var sun:Vector3=-Vector3.RIGHT*sin(theta)+meridian*cos(theta)
 var moon:Vector3=-Vector3.RIGHT*sin(theta-elongation)+meridian*cos(theta-elongation)
 # Artistic fixed-latitude equinox; lunar orbit has zero inclination. Not ephemerides.
 return {"sun":sun,"moon":moon,"pole":pole,"meridian":meridian,"angle":theta,"phase":(1.0-cos(elongation))*0.5}
func export_state() -> Dictionary:
 return {"seed":seed_value,"lunar_days":lunar_days,"initial_phase":initial_phase,"latitude":latitude,"epoch":epoch,"previous_rain":previous_rain,"rain_style":rain_style,"dry_style":dry_style,"from_cloud":from_cloud,"from_rain":from_rain,"from_fog":from_fog,"from_wind":from_wind,"transition_start":transition_start}
func import_state(data:Dictionary,clock:float,raining:bool) -> void:
 reset(clock,raining)
 for key in ["lunar_days","initial_phase","latitude","epoch","from_cloud","from_rain","from_fog","from_wind","transition_start"]:
  if data.has(key):set(key,float(data[key]))
 seed_value=int(data.get("seed",41873));previous_rain=bool(data.get("previous_rain",raining))
 lunar_days=maxf(1,lunar_days);latitude=clampf(latitude,-80,80)
 rain_style=str(data.get("rain_style","light_rain"));dry_style=str(data.get("dry_style","clear"))
 if rain_style not in ["light_rain","heavy_rain","storm"]:rain_style="light_rain"
 if dry_style not in ["clear","broken","mist"]:dry_style="clear"
