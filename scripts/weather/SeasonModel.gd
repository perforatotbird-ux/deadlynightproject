extends RefCounted
# Deterministic seasons derived from the world clock. No own state, no RNG,
# no save fields: the clock alone decides season, daylight span and air temperature.
# Spring reproduces the pre-season legacy curve exactly (4..15 °C, dawn 5-7, dusk 18-20).
const SEASON_DAYS := 8
const SEASON_SECONDS := SEASON_DAYS*86400.0
const CYCLE_SECONDS := SEASON_SECONDS*4.0
const NAMES := ["весна", "лето", "осень", "зима"]
# Indexed by the season that is ARRIVING, i.e. the new season_index().
const ARRIVAL := [
 "Наступает весна. Лёд тает, день прибывает.",
 "Наступает лето. Длинные дни, тёплые ночи.",
 "Наступает осень. Чаще туманы и ветер, ночи холоднеют.",
 "Наступает зима. Короткий день, мороз, дров уходит больше."]
# Half-width of the blend window at a season boundary, in world seconds.
const TRANSITION_SECONDS := 6.0*3600.0
# [night, day] air temperature °C at rain=0
# Winter is a damp European frost, not an arctic one: the authored cabin has no
# heating, and ThermalModel only adds +5 °C for a closed door. At -12 °C even the
# interior would drain warmth to zero inside 45 game minutes and make winter sleep
# impossible. -5/+1 keeps winter clearly harsher than spring while the shelter
# stays survivable and short naps still work.
const AIR := [[4.0,15.0],[9.0,21.0],[2.0,9.0],[-5.0,1.0]]
# [dawn_start, dawn_end, dusk_start, dusk_end] in hours; daylight is smoothstep
# between them, identical in shape to the legacy spring formula.
const DAYLIGHT := [
 [5.0,7.0,18.0,20.0],
 [4.0,6.0,19.5,21.5],
 [5.5,7.5,16.5,19.0],
 [7.5,9.5,15.0,17.0]]
# Base wind strength 0..1 before weather boost and gusts.
const WIND := [[0.25],[0.15],[0.45],[0.6]]
# Sun/ambient tint and energy scale per season (SkyRenderer consumes).
const SUN_TINT := [Color(1.0,1.0,1.0),Color(1.0,0.97,0.88),Color(1.0,0.9,0.74),Color(0.82,0.88,1.05)]
const SUN_ENERGY := [[1.0],[1.0],[0.85],[0.6]]
# Weather style cutoffs in the visual model's 0..99 pick per season:
# rain pick < storm_cut -> storm, < heavy_cut -> heavy_rain; dry pick < mist_cut
# -> mist, < broken_cut -> broken. Season 0 keeps the legacy thresholds exactly.
const STYLE_STORM := [18,22,28,10]
const STYLE_HEAVY := [53,60,62,45]
const STYLE_MIST := [20,8,35,30]
const STYLE_BROKEN := [65,55,70,60]

static func season_index(clock:float) -> int:
 return int(fposmod(floorf(maxf(0.0,clock)/86400.0)/SEASON_DAYS,4.0))

static func season_day(clock:float) -> int:
 return int(fposmod(clock,SEASON_SECONDS)/86400.0)+1

static func season_progress(clock:float) -> float:
 return fposmod(clock,SEASON_SECONDS)/SEASON_SECONDS

static func _blend(clock:float) -> float:
 # 0 almost everywhere; ramps to 1 across the last TRANSITION_SECONDS of the
 # season so every seasonal parameter is continuous at the boundary.
 var pos := fposmod(clock,SEASON_SECONDS)
 return smoothstep(SEASON_SECONDS-TRANSITION_SECONDS,SEASON_SECONDS,pos)

static func _blended(clock:float,values:Array) -> Array:
 var i := season_index(clock)
 var j := (i+1)%4
 var b := _blend(clock)
 var out:Array = []
 for k in values[i].size():
  out.append(lerpf(float(values[i][k]),float(values[j][k]),b))
 return out

static func daylight(clock:float) -> float:
 var w := _blended(clock,DAYLIGHT)
 var h := fposmod(clock,86400.0)/3600.0
 return smoothstep(w[0],w[1],h)*(1.0-smoothstep(w[2],w[3],h))

static func air_temperature(clock:float,day_factor:float,rain:float) -> float:
 var a := _blended(clock,AIR)
 return lerpf(float(a[0]),float(a[1]),clampf(day_factor,0,1))-3.0*clampf(rain,0,1)

static func wind_base(clock:float) -> float:
 return float(_blended(clock,WIND)[0])

static func sun_tint(clock:float) -> Color:
 var i := season_index(clock)
 var j := (i+1)%4
 return SUN_TINT[i].lerp(SUN_TINT[j],_blend(clock))

static func sun_energy_scale(clock:float) -> float:
 return float(_blended(clock,SUN_ENERGY)[0])

static func style_cuts(clock:float) -> Dictionary:
 var i := season_index(clock)
 var j := (i+1)%4
 var b := _blend(clock)
 return {
  "storm":lerpf(float(STYLE_STORM[i]),float(STYLE_STORM[j]),b),
  "heavy":lerpf(float(STYLE_HEAVY[i]),float(STYLE_HEAVY[j]),b),
  "mist":lerpf(float(STYLE_MIST[i]),float(STYLE_MIST[j]),b),
  "broken":lerpf(float(STYLE_BROKEN[i]),float(STYLE_BROKEN[j]),b)}
