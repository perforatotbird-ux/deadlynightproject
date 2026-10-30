extends SceneTree
var passes:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;print("FAIL: "+label)
func run() -> void:
 var sm=load("res://scripts/core/SettingsManager.gd").get_instance()
 await process_frame
 var screen=load("res://scripts/menu/SettingsScreen.gd").new();root.add_child(screen)
 await process_frame;await process_frame
 check(screen._opt_sky.item_count==3 and screen._opt_rain.item_count==3,"quality controls have three supported profiles")
 screen._opt_sky.selected=0;screen._opt_rain.selected=2;screen._chk_lightning.button_pressed=true;screen._slider_weather.value=0.3;screen._slider_thunder.value=0.4
 # Apply directly to the manager through the same UI callback used by the button.
 screen._on_apply_pressed()
 check(sm.get_setting("graphics","sky_quality")==0 and sm.get_setting("graphics","rain_quality")==2,"UI applies sky and rain quality")
 check(sm.get_setting("graphics","reduced_lightning"),"UI applies reduced lightning")
 check(absf(float(sm.get_setting("audio","weather_volume"))-0.3)<0.001 and absf(float(sm.get_setting("audio","thunder_volume"))-0.4)<0.001,"separate weather and thunder gains apply")
 sm.save_to_disk();sm.reset_to_defaults(false);sm.load_from_disk()
 check(sm.get_setting("graphics","reduced_lightning") and sm.get_setting("graphics","sky_quality")==0,"weather settings survive disk reload")
 screen.queue_free();await process_frame;await process_frame
 print("WEATHER SETTINGS SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit.call_deferred(1 if failures else 0)
