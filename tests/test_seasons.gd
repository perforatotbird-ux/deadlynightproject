extends SceneTree
const Season=preload("res://scripts/weather/SeasonModel.gd")
const Wind=preload("res://scripts/weather/WindModel.gd")
const Fire=preload("res://scripts/survival/FireModel.gd")
const Thermal=preload("res://scripts/survival/ThermalModel.gd")
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;printerr("FAIL: "+label)
func legacy_daylight(clock:float) -> float:
 var h:=fposmod(clock,86400.0)/3600.0
 return smoothstep(5.0,7.0,h)*(1.0-smoothstep(18.0,20.0,h))
func run():
 # --- season indexing ---------------------------------------------------
 check(Season.season_index(0)==0 and Season.season_index(16*3600)==0,"new game starts in spring")
 check(Season.season_index(8.0*86400)==1 and Season.season_index(16.0*86400)==2 and Season.season_index(24.0*86400)==3,"seasons change every 8 game days")
 check(Season.season_index(32.0*86400)==0 and Season.season_index(40.0*86400)==1,"season cycle repeats every 32 days")
 check(Season.season_day(9.0*86400)==2 and absf(Season.season_progress(9.0*86400)-(1.0/8.0))<0.001,"day-in-season and progress follow the clock")
 check(Season.NAMES.size()==4 and Season.NAMES[0]=="весна" and Season.NAMES[3]=="зима","all four season names defined")
 # --- spring keeps the legacy curve exactly ------------------------------
 var legacy_ok:=true
 for clock in [0.0,5.5*3600,6.5*3600,12.0*3600,19.0*3600,21.0*3600,23.5*3600]:
  if absf(Season.daylight(clock)-legacy_daylight(clock))>0.00001:legacy_ok=false
 check(legacy_ok,"spring daylight reproduces the legacy 5-7/18-20 smoothstep curve")
 var legacy_air_ok:=true
 for clock in [0.0,6.0*3600,12.0*3600,19.0*3600]:
  var expected:=lerpf(4.0,15.0,legacy_daylight(clock))-3.0*0.5
  if absf(Season.air_temperature(clock,legacy_daylight(clock),0.5)-expected)>0.00001:legacy_air_ok=false
 check(legacy_air_ok,"spring air temperature reproduces the legacy 4..15°C formula")
 # --- seasonal daylight span ----------------------------------------------
 var summer_day:=Season.season_index(10.0*86400+12.0*3600)==1
 var summer_17:=Season.daylight(10.0*86400+17.0*3600)
 var winter_17:=Season.daylight(26.0*86400+17.0*3600)
 check(summer_day and summer_17>0.9 and winter_17<0.1,"summer is still bright at 17:00 while winter is already dark")
 check(Season.daylight(26.0*86400+12.0*3600)>0.95,"winter noon is full daylight")
 check(Season.daylight(10.0*86400+5.0*3600)>0.4 and Season.daylight(26.0*86400+5.0*3600)<0.1,"summer dawn comes hours before winter dawn")
 # --- seasonal air temperature ---------------------------------------------
 var summer_noon:=Season.air_temperature(10.0*86400+12.0*3600,1.0,0.0)
 var winter_noon:=Season.air_temperature(26.0*86400+12.0*3600,1.0,0.0)
 var winter_night:=Season.air_temperature(26.0*86400+0.0*3600,0.0,0.0)
 check(summer_noon-winter_noon>10.0,"winter noon is at least 10°C colder than summer noon")
 check(winter_night<=-4.0,"winter night is a genuine frost")
 var rain_cold:=Season.air_temperature(26.0*86400+12.0*3600,1.0,1.0)
 check(rain_cold<winter_noon,"precipitation still subtracts 3°C in every season")
 # --- continuity across season boundaries ----------------------------------
 var continuity:=true
 for day in [8,16,24,32]:
  var before:=Season.air_temperature(day*86400.0-1.0,Season.daylight(day*86400.0-1.0),0.0)
  var after:=Season.air_temperature(day*86400.0+1.0,Season.daylight(day*86400.0+1.0),0.0)
  if absf(after-before)>0.5:continuity=false
 check(continuity,"air temperature is continuous across every season boundary")
 var light_continuity:=true
 for day in [8,16,24,32]:
  for h in [0.0,6.0,12.0,18.0]:
   var t:float=day*86400.0+h*3600
   if absf(Season.daylight(t-0.5)-Season.daylight(t+0.5))>0.02:light_continuity=false
 check(light_continuity,"daylight factor is continuous across every season boundary")
 # --- wind model -------------------------------------------------------------
 var w1:=Wind.sample(12345.0,0.45,0.0,0.0)
 var w2:=Wind.sample(12345.0,0.45,0.0,0.0)
 check(w1==w2,"wind is deterministic for the same clock and inputs")
 var bounded:=true
 for i in 200:
  var w:=Wind.sample(i*97.3,0.45,float(i%5)*0.25,float(i%3)*0.5)
  if float(w.strength)<0.0 or float(w.strength)>1.0 or absf(w.direction.length()-1.0)>0.001:bounded=false
 check(bounded,"wind strength stays in 0..1 and direction stays unit-length")
 var day_a:=Wind.sample(50000.0,0.45,0.0,0.0)
 var day_b:=Wind.sample(50000.0+2.5*86400.0,0.45,0.0,0.0)
 check(absf(float(day_a.angle_deg)-float(day_b.angle_deg))>20.0,"wind direction drifts over days")
 var storm_wind:=Wind.sample(60000.0,0.45,1.0,1.0)
 var calm_wind:=Wind.sample(60000.0,0.45,0.0,0.0)
 check(float(storm_wind.strength)>float(calm_wind.strength),"storm weather strengthens the wind")
 var head:=Wind.headwind(Vector3(1,0,0),Vector3(-1,0,0))
 var tail:=Wind.headwind(Vector3(1,0,0),Vector3(1,0,0))
 check(head>0.99 and tail<-0.99,"headwind sign: opposing the wind is positive")
 var mult_head:=Wind.movement_multiplier(Vector3(1,0,0),1.0,Vector3(-1,0,0))
 var mult_tail:=Wind.movement_multiplier(Vector3(1,0,0),1.0,Vector3(1,0,0))
 check(mult_head>=0.89 and mult_head<1.0 and mult_tail>1.0 and mult_tail<=1.051,"headwind slows up to 10%, tailwind helps up to 5%")
 check(Wind.strength_word(0.05)=="штиль" and Wind.strength_word(0.9)=="штормовой","wind strength words cover the scale")
 check(Wind.compass(Vector3(-1,0,0))=="В" and Wind.compass(Vector3(0,0,1))=="С" and Wind.compass(Vector3(0,0,-1))=="Ю","wind compass names the origin like the player compass")
 # --- fire in wind -------------------------------------------------------------
 var f1:=Fire.create("a",Vector3.ZERO);f1.state="burning";f1.fuel=1000
 var f2:=f1.duplicate(true)
 Fire.advance(f1,100,false,0.0,0.0);Fire.advance(f2,100,false,0.0,1.0)
 check(float(f1.fuel)>float(f2.fuel),"wind makes a fire burn fuel faster")
 check(Fire.chance("match",0,false,0.0,1.0)<Fire.chance("match",0,false,0.0,0.0),"wind lowers ignition chance")
 check(is_equal_approx(Fire.time_to_change({"state":"burning","fuel":130.0},0.0,1.0),100.0),"time_to_change and advance agree on the wind burn rate")
 var calm:=Thermal.step(0,60,5,0,0.0,0,false,false,false)
 var windy:=Thermal.step(0,60,5,0,1.0,0,false,false,false)
 check(float(windy.felt)<float(calm.felt),"wind chill lowers felt temperature in the open")
 var roof:=Thermal.step(0,60,5,0,1.0,0,true,false,false)
 check(float(roof.wind_chill)==0.0,"a roof still neutralises wind chill")
 # Balance guard: winter must stay survivable indoors. The authored cabin has no
 # heating, so a closed door is the only protection; a one-hour nap has to fit.
 var winter_inside:=Thermal.step(0,3600,Season.AIR[3][0],0,0.6,0,true,true,false)
 var winter_outside:=Thermal.step(0,3600,Season.AIR[3][0],0,0.6,0,false,false,false)
 check(float(winter_inside.warmth_delta)>-80.0,"winter night in a closed shelter still allows a one-hour nap")
 check(float(winter_outside.warmth_delta)<float(winter_inside.warmth_delta)-40.0,"winter night outside is far harsher than the shelter")
 # --- world integration ---------------------------------------------------------
 var scene:=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");scene.add_child(ground)
 var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(150,1,150);col.shape=box;col.position.y=-0.5;ground.add_child(col)
 var p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(0,0.2,2)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();scene.add_child(s);s.set_process(false);s.vegetation.set_physics_process(false);s.shelter.position=Vector3(40,0,40)
 await physics_frame;await process_frame
 check(s.season_name()=="весна" and s.season_day()==1,"new game reports spring day 1")
 check(absf(s.daylight()-legacy_daylight(s.clock))<0.00001,"world daylight delegates to the legacy spring curve")
 s.clock=23*3600;s.weather="rain";s.weather_until=s.clock+100000;s.weather_model.reset(s.clock,true);s.weather_model.rain_style="storm"
 var air_now:float=s.air_temperature()
 check(absf(air_now-(4.0-3.0*s.rain_intensity()))<0.01,"spring storm night keeps the legacy 4°C-rain air temperature")
 var w:Dictionary=s.wind()
 check(float(w.strength)>0.5,"storm in the world produces a strong wind")
 s._update_lighting()
 check(absf(float(s.weather_visual.wind)-float(w.strength))<0.01,"visual weather carries the real wind, not the profile constant")
 check(s.weather_visual.wind_direction.length()>0.99,"visual weather carries a real wind direction for rain drift")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()))
 check(int(saved.get("version",0))==4 and not saved.has("season"),"seasons add no save fields: payload stays v4, season is derived from clock")
 s.clock=10.0*86400+12*3600;s.weather="clear";s.weather_until=s.clock+100000;s.weather_model.reset(s.clock,false)
 check(s.season_name()=="лето" and s.season_day()==3,"clock set to day 10 reports summer day 3")
 var air_summer:float=s.air_temperature()
 check(air_summer>18.0,"summer noon in the world is warm")
 s.clock=26.0*86400+1*3600
 check(s.season_name()=="зима","clock set to day 26 reports winter")
 check(s.air_temperature()<-4.0,"winter night in the world is below -4°C")
 s.import_state(saved)
 check(s.season_name()=="весна","loading a spring save restores spring without any stored season field")
 var has_season_notice:bool=("весна" in s.message) or ("лето" in s.message) or ("осень" in s.message) or ("зима" in s.message)
 check(not has_season_notice,"loading does not fire a season-change notification")
 s.advance(0.01)
 check(s._last_season==s.season_index(),"first advance after load anchors the season tracker")
 s.clock=7.0*86400+12*3600;s._last_season=-1;s.advance(0.01)
 check(s._last_season==0,"season tracker anchors to spring before the boundary")
 s.clock=8.0*86400-0.01;s.advance(0.01)
 check(s._last_season==1 and "лето" in s.message,"crossing into summer notifies the player exactly once")
 s.clock=8.0*86400+100;s.advance(0.01)
 check(s._last_season==1,"no repeated season notification within the same season")
 scene.free();current_scene=null;await process_frame
 print("SEASONS SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
