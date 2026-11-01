extends Node3D
# Sole writer of exterior Environment, sun and moon. Mine environment is untouched.
const SeasonModel=preload("res://scripts/weather/SeasonModel.gd")
static var _star_cubes:Dictionary={}
var session:Node
var model:RefCounted
var material:ShaderMaterial
var moon:DirectionalLight3D
var environment:Environment
var sun:DirectionalLight3D
var quality:=1
var last:Dictionary={}
var _applied_flash:=0.0
func _ready() -> void:
 name="SkyRenderer"
 if session.location!="forest":return
 var scene:Node=session.get_parent()
 var envnode:WorldEnvironment=scene.get_node_or_null("WorldEnvironment")
 sun=scene.get_node_or_null("DirectionalLight3D")
 if envnode==null:return
 # Local copies avoid resource mutations leaking into a new forest scene.
 environment=envnode.environment.duplicate(true);envnode.environment=environment
 material=ShaderMaterial.new();material.shader=preload("res://shaders/sky/living_sky.gdshader")
 quality=clampi(int(load("res://scripts/core/SettingsManager.gd").get_instance().get_setting("graphics","sky_quality",1)),0,2)
 material.set_shader_parameter("stars",star_texture(quality))
 material.set_shader_parameter("milky_way",preload("res://assets/sky/milky_way.png"))
 material.set_shader_parameter("moon_map",preload("res://assets/sky/moon.png"))
 var sky:=Sky.new();sky.sky_material=material;sky.radiance_size=Sky.RADIANCE_SIZE_32
 sky.process_mode=Sky.PROCESS_MODE_REALTIME;environment.sky=sky
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_sky_contribution=0
 environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
 moon=DirectionalLight3D.new();moon.name="MoonLight";moon.light_color=Color(0.62,0.73,0.93);add_child(moon)
func update_sky(state:Dictionary,flash:float=0.0) -> void:
 if environment==null:return
 last=state
 var sm=load("res://scripts/core/SettingsManager.gd").get_instance()
 quality=clampi(int(sm.get_setting("graphics","sky_quality",1)),0,2)
 var body:Dictionary=model.celestial(session.clock)
 var day:float=session.daylight();var clouds:float=state.cloud
 var tint:Color=SeasonModel.sun_tint(session.clock)
 var energy_scale:float=SeasonModel.sun_energy_scale(session.clock)
 material.set_shader_parameter("quality",quality)
 material.set_shader_parameter("stars",star_texture(quality))
 material.set_shader_parameter("milky_way",preload("res://assets/sky/milky_way_low.png") if quality==0 else preload("res://assets/sky/milky_way.png"))
 material.set_shader_parameter("sun_dir",body.sun);material.set_shader_parameter("moon_dir",body.moon)
 material.set_shader_parameter("pole",body.pole);material.set_shader_parameter("meridian",body.meridian)
 material.set_shader_parameter("angle",body.angle);material.set_shader_parameter("day",day)
 material.set_shader_parameter("cloud_cover",clouds);material.set_shader_parameter("world_seconds",fposmod(session.clock,86400.0*100.0))
 material.set_shader_parameter("flash",flash)
 if sun:
  _aim(sun,body.sun)
  sun.light_energy=1.3*day*smoothstep(-0.05,0.12,body.sun.y)*(1.0-clouds*0.6)*energy_scale+flash*0.35
  sun.light_color=Color(1,0.68,0.42).lerp(Color(1,0.93,0.78),smoothstep(0.0,0.4,body.sun.y))*tint
  sun.directional_shadow_max_distance=[40.0,70.0,110.0][quality]
 _aim(moon,body.moon)
 moon.light_energy=0.09*body.phase*smoothstep(0.0,0.35,body.moon.y)*(1.0-day)*(1.0-clouds*0.85)
 # One shadow caster at a time, bounded to nearby forest geometry.
 moon.shadow_enabled=quality>0 and int(sm.get_setting("graphics","shadow_quality",2))>0 and moon.light_energy>0.015 and day<0.1
 moon.directional_shadow_max_distance=45 if quality==1 else 70
 moon.shadow_blur=2.0
 environment.ambient_light_energy=lerpf(0.05,0.7,day)*(1.0-clouds*0.3)+flash*0.07
 environment.ambient_light_color=Color(0.3,0.4,0.65).lerp(Color(0.7,0.75,0.8),day)*tint
 environment.fog_light_color=Color(0.025,0.04,0.065).lerp(Color(0.65,0.72,0.8),day)*tint
 environment.fog_density=state.fog
 _applied_flash=flash
func _aim(light:DirectionalLight3D,direction:Vector3) -> void:
 var up:=Vector3.UP if absf(direction.dot(Vector3.UP))<0.99 else Vector3.FORWARD
 light.quaternion=Quaternion(Basis.looking_at(-direction,up))

func apply_flash(value:float) -> void:
 if environment==null:return
 var difference:=value-_applied_flash
 if sun:sun.light_energy=maxf(0,sun.light_energy+difference*0.35)
 environment.ambient_light_energy=maxf(0,environment.ambient_light_energy+difference*0.07)
 material.set_shader_parameter("flash",value)
 _applied_flash=value

static func star_texture(profile:int) -> Cubemap:
 var level:=0 if profile==0 else 1
 if _star_cubes.has(level):return _star_cubes[level]
 var images:Array[Image]=[]
 for face in ["px","nx","py","ny","pz","nz"]:
  var texture:Texture2D=load("res://assets/sky/stars_"+face+".png")
  var image:Image=texture.get_image()
  image.convert(Image.FORMAT_RGB8)
  if level==0:image.resize(256,256,Image.INTERPOLATE_LANCZOS)
  image.generate_mipmaps();images.append(image)
 var cube:=Cubemap.new();var error:=cube.create_from_images(images)
 assert(error==OK,"Star cubemap construction failed")
 _star_cubes[level]=cube;return cube
