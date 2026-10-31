extends RefCounted
# Gameplay intervals, in WORLD seconds. Visual WeatherModel consumes no RNG.
# Dry breaks dominate; rain is an event rather than every other long period.
const FIRST_DRY_SECONDS:=6.0*3600.0
const DRY_HOURS:=Vector2(6.0,10.0)
const RAIN_HOURS:=Vector2(0.75,1.75)
static func duration(kind:String,rng:RandomNumberGenerator) -> float:
 var span:Vector2=RAIN_HOURS if kind=="rain" else DRY_HOURS
 return rng.randf_range(span.x,span.y)*3600.0
