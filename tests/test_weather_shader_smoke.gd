extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.look_at(Vector3(0,0.67,-0.74),Vector3.UP)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY
 var sky:=Sky.new();var material:=ShaderMaterial.new();material.shader=load("res://shaders/sky/living_sky.gdshader")
 material.set_shader_parameter("stars",load("res://scripts/weather/SkyRenderer.gd").star_texture(1));material.set_shader_parameter("moon_map",load("res://assets/sky/moon.png"));material.set_shader_parameter("milky_way",load("res://assets/sky/milky_way.png"))
 sky.sky_material=material;env.environment.sky=sky;scene.add_child(env)
 for strength in [0.0,0.8,0.0]:
  material.set_shader_parameter("bolt_strength",strength)
  for i in 3:await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/data/weather-pole-smoke.png")
 scene.queue_free();for i in 3:await process_frame
 print("WEATHER SHADER SMOKE: completed native draw, no CPU-only substitution")
 quit.call_deferred()
