extends RefCounted
# Deterministic wind: a pure function of the world clock, season base and
# current precipitation. No RNG, no save state — a loaded game at the same
# clock always reproduces the same wind, matching the rest of the weather stack.
# Wind blows TOWARD `direction`; compass names use the origin (meteorology).
const MAX_SPEED_MS := 12.0

static func sample(clock:float,base:float,rain:float,storm:float) -> Dictionary:
 base = clampf(base,0.0,1.0)
 var gust_a := 0.5+0.5*sin(clock*0.0021+base*7.0)
 var gust_b := 0.5+0.5*sin(clock*0.0113+2.7)
 var strength := clampf(base+0.35*clampf(rain,0,1)+0.25*clampf(storm,0,1)+0.16*gust_a*gust_b-0.08,0.0,1.0)
 var angle := fposmod(clock*0.00042+sin(clock*0.00009)*1.1+base*2.0,TAU)
 return {"strength":strength,"gust":gust_b,"direction":Vector3(cos(angle),0,sin(angle)),"angle_deg":rad_to_deg(angle),"speed_ms":strength*MAX_SPEED_MS}

static func headwind(direction:Vector3,move_dir:Vector3) -> float:
 # +1 moving exactly against the wind, -1 exactly with it.
 var d := Vector3(direction.x,0,direction.z)
 var m := Vector3(move_dir.x,0,move_dir.z)
 if m.length_squared()<0.0001 or d.length_squared()<0.0001:return 0.0
 return -d.normalized().dot(m.normalized())

static func movement_multiplier(direction:Vector3,strength:float,move_dir:Vector3) -> float:
 # Headwind resists, tailwind barely helps; deliberately small so balance
 # stays readable: -10% .. +5%.
 var head := headwind(direction,move_dir)
 return clampf(1.0-head*clampf(strength,0,1)*0.10,0.90,1.05)

static func strength_word(strength:float) -> String:
 if strength<0.12:return "штиль"
 if strength<0.35:return "слабый"
 if strength<0.6:return "умеренный"
 if strength<0.82:return "сильный"
 return "штормовой"

static func compass(direction:Vector3) -> String:
 # Named by ORIGIN (meteorology): a wind blowing eastward is a westerly wind.
 # Godot world convention matches the player compass: -Z is north, +X is east.
 var dirs := ["С","СВ","В","ЮВ","Ю","ЮЗ","З","СЗ"]
 var az := fposmod(rad_to_deg(atan2(direction.x,-direction.z)),360.0)
 var origin := fposmod(az+180.0,360.0)
 return dirs[int(origin/45.0+0.5)%8]

static func describe(state:Dictionary) -> String:
 return "%s · %.1f м/с, %s" % [strength_word(float(state.strength)),float(state.speed_ms),compass(state.direction)]
