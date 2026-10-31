extends SceneTree
const Thermal=preload("res://scripts/survival/ThermalModel.gd")
const Schedule=preload("res://scripts/weather/WeatherSchedule.gd")
const Fire=preload("res://scripts/survival/FireModel.gd")
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;printerr("FAIL: "+label)
func configure(s:Node,kind:String):
 s.weather="rain" if kind in ["light_rain","heavy_rain","storm"] else "clear"
 s.weather_until=s.clock+100000;s.weather_model.reset(s.clock,s.weather=="rain")
 if s.weather=="rain":s.weather_model.rain_style=kind
func run():
 check(Thermal.fire_heat(1,"burning")==Thermal.fire_heat(1.5,"burning"),"comfort zone does not require standing inside fire")
 check(Thermal.fire_heat(2,"burning")>Thermal.fire_heat(3,"burning"),"heat decreases beyond comfort zone")
 check(Thermal.fire_heat(4.5,"burning")==0 and Thermal.fire_heat(1,"cold")==0,"no heat from distant/cold fire")
 check(Thermal.fire_heat(1,"embers")<Thermal.fire_heat(1,"burning"),"embers never equal a burning fire")
 var rain:=Thermal.step(100,60,1,Thermal.fire_heat(2,"burning"),1,1,false,false,false)
 check(rain.wetness<100 and rain.warmth_delta>0,"fully soaked player warms AND dries at 2m in night storm")
 var exposed:=Thermal.step(50,60,1,0,1,1,false,false,false)
 check(exposed.wetness>50 and exposed.warmth_delta<0,"storm still wets and chills without fire")
 var drizzle:=Thermal.step(50,60,2.95,0,0.4,0.35,false,false,false)
 check(drizzle.wetness<exposed.wetness and drizzle.warmth_delta>exposed.warmth_delta,"drizzle is less wetting/chilling than a storm")
 var dry_night:=Thermal.step(0,60,4,0,0.12,0,false,false,false)
 var dry_day:=Thermal.step(0,60,15,0,0.12,0,false,false,false)
 check(dry_night.warmth_delta<0 and dry_day.warmth_delta>0,"spring daytime and nighttime remain meaningfully different")
 var roof:=Thermal.step(50,60,1,0,1,1,true,false,false)
 check(roof.wetness<50 and roof.wind_chill==0,"roof blocks rain and direct wind but does not magically dry instantly")
 var closed:=Thermal.step(50,60,1,0,1,1,true,true,false)
 check(closed.felt>roof.felt,"closed shelter adds insulation independently of roof")
 var mine:=Thermal.step(50,60,-20,32,1,1,false,false,true)
 check(mine.wetness<50 and mine.felt>5 and mine.felt<8,"mine has its own damp temperature, no outdoor weather/heat")
 var a:=Thermal.step(2,600,4,32,1,0,false,false,false)
 var w:=2.0;var delta:=0.0
 for i in 600:
  var t:=Thermal.step(w,1,4,32,1,0,false,false,false);w=t.wetness;delta+=float(t.warmth_delta)
 check(absf(w-float(a.wetness))<0.00001 and absf(delta-float(a.warmth_delta))<0.00001,"drying boundary integrates consistently at 1s and 10min")
 var wet:=100.0;var warmth:=20.0;var minutes:=0
 while warmth<60 and minutes<120:
  var t:=Thermal.step(wet,60,1,Thermal.fire_heat(2,"burning"),1,1,false,false,false);wet=t.wetness;warmth=clampf(warmth+float(t.warmth_delta),0,100);minutes+=1
 print("THERMAL CALIBRATION: 20->60 warmth in ",minutes," game minutes / real seconds at TIME_SCALE=60; 2m, storm, full initial wetness; remaining wetness=",wet)
 check(minutes<=60 and wet<100,"fire recovery is usable without removing storm risk")
 var rng:=RandomNumberGenerator.new();rng.seed=20261031;var dry:=0.0;var rainy:=0.0;var bounded:=true
 for i in 10000:
  var d:=Schedule.duration("clear",rng);var r:=Schedule.duration("rain",rng);dry+=d;rainy+=r
  bounded=bounded and d>=6*3600 and d<=10*3600 and r>=45*60 and r<=105*60
 check(bounded,"all schedule intervals obey dry 6-10h / rain 45-105min bounds")
 var share:=rainy/(rainy+dry)
 print("WEATHER SCHEDULE: seed20261031, 10000 cycles, rain fraction=",share)
 check(share>0.12 and share<0.15,"rain no longer occupies approximately half of the schedule")
 var copy:=RandomNumberGenerator.new();copy.state=rng.state
 check(Schedule.duration("rain",copy)==Schedule.duration("rain",rng),"persisted RNG resumes the same next interval")
 var f:=Fire.create("test",Vector3.ZERO);f.state="burning";f.fuel=150
 Fire.advance(f,60,true,0.35);check(is_equal_approx(float(f.fuel),79.5),"light rain fuel penalty is proportional to rendered rain")
 check(Fire.chance("match",0,true,0.35)>Fire.chance("match",0,true,1),"light rain does not get full storm ignition penalty")
 var scene:=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");scene.add_child(ground);var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(150,1,150);col.shape=box;col.position.y=-0.5;ground.add_child(col)
 var p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(0,0.2,2)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();scene.add_child(s);s.set_process(false);s.vegetation.set_physics_process(false);s.shelter.position=Vector3(40,0,40)
 await physics_frame;await process_frame
 check(s.weather_until-s.clock==Schedule.FIRST_DRY_SECONDS,"new game has a six-hour first dry window")
 s.clock=23*3600;configure(s,"storm");s.warmth=20;s.wetness=100
 f=Fire.create("real",Vector3(0,0.05,0));f.state="burning";f.fuel=10000;s.fires=[f]
 var heat:float=s.heat_at_player();s.advance(30)
 print("WORLD THERMAL: heat=",heat," warmth=",s.warmth," wetness=",s.wetness)
 check(heat>25 and s.warmth>60 and s.wetness<50,"real world tick warms/dries storm-exposed player without sleep or Dev time")
 var barrier:=StaticBody3D.new();var wall:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(3,3,0.2);wall.shape=shape;barrier.position=Vector3(0,1.5,1);barrier.add_child(wall);scene.add_child(barrier);await physics_frame;await physics_frame
 check(s.heat_at_player()==0,"wall blocks heat, not just interaction")
 barrier.free();await physics_frame;await physics_frame
 p.position=Vector3(0,0.2,6);check(s.heat_at_player()==0,"player outside heat radius cannot warm from this fire")
 p.position=Vector3(0,0.2,2);s.clock=23*3600;configure(s,"clear");s.wetness=80;s.warmth=30;f.fuel=30;f.state="burning"
 var old:float=s.warmth;s.advance(0.5)
 check(f.state=="embers" and s.warmth>old,"last half-minute of burning fuel supplies burning heat before embers")
 # Existing active weather/save fields and visual transition remain authoritative.
 s.clock=23*3600;configure(s,"storm");s.weather_until=s.clock+1800
 var saved:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()));s.import_state(saved)
 check(s.weather=="rain" and s.weather_until==float(saved.weather_until) and s.rng.state==int(saved.rng_state),"save preserves active rain deadline and RNG rather than rerolling")
 s.body.freeze_needs=true;s.fires=[];s.weather="clear";s.weather_until=s.clock+30;s.weather_model.reset(s.clock,false)
 var boundary:float=s.weather_until;s.advance(1)
 check(s.weather=="rain" and s.weather_until>=boundary+45*60 and s.weather_until<=boundary+105*60,"weather boundary uses new interval without one-minute delay")
 s.weather="clear";s.weather_until=s.clock+60;s.weather_model.reset(s.clock,false);s.advance(1)
 check(s.weather=="rain" and s.weather_until>s.clock,"exact final-step deadline changes weather immediately")
 check(s.rain_intensity()==0,"rain onset does not apply a full storm penalty before visible precipitation")
 s.advance(15);check(s.rain_intensity()>0,"precipitation builds during visual transition")
 s.weather="clear";s.weather_until=s.clock+10000
 check(s.rain_intensity()>0,"wetting intensity fades out instead of vanishing on binary switch")
 s.advance(15);check(s.rain_intensity()==0,"clear weather has no lingering rain penalty after transition")
 configure(s,"clear");s.weather_model.dry_style="mist";s.ui.refresh()
 check(s.weather_description()=="туман" and "туман" in s.ui.hud.text,"HUD reports actual dry weather profile instead of always clear")
 var status:String=s.thermal_description();check("игр. мин" in status and "ощущается" in status,"condition diagnostics explain temperature and actual rates")
 s.warmth=100;s.wetness=0;s.clock=12*3600;configure(s,"clear")
 check(s.thermal_description().count("+0.0%")>=2,"diagnostics respect saturated warmth and dry clothing limits")
 # Same one-hour rest, one call vs many calls: the clock is the only authority.
 p.global_position=s.shelter.global_position+Vector3(0,0.2,0);s.shelter.set_door(true);s.body.freeze_needs=false;s.health=100;s.body.food=100;s.body.water=100;s.warmth=75;s.wetness=50;s.energy=20;configure(s,"clear")
 s.open_sleep(s.shelter.bed);check(s.begin_rest(),"rest fixture uses the real bed")
 saved=JSON.parse_string(JSON.stringify(s.export_state()));s.advance(1);var single:=Vector3(s.clock,s.wetness,s.warmth)
 s.import_state(saved)
 for i in 60:s.advance(1.0/60)
 check(absf(s.clock-single.x)<0.01 and absf(s.wetness-single.y)<0.03 and absf(s.warmth-single.z)<0.05,"accelerated sleep agrees across caller frame sizes")
 scene.free();current_scene=null;await process_frame
 print("WEATHER TEMPERATURE SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
