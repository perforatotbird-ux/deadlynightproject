extends RefCounted
# Gameplay comfort reserve, NOT core body temperature or a clothing simulation.
# All rates are per GAME minute; caller owns the sole world clock.
const HEAT_RADIUS:=4.5
const COMFORT_RADIUS:=1.5
const BURNING_HEAT:=32.0
const EMBER_HEAT:=6.0
const NEUTRAL_FELT:=7.0
const WARMTH_RESPONSE:=0.16
const RAIN_WETTING:=1.5
const PASSIVE_DRYING:=0.25
const FIRE_DRYING:=0.12
static func fire_heat(distance:float,state:String) -> float:
 if state not in ["burning","embers"]:return 0.0
 var falloff:=clampf((HEAT_RADIUS-maxf(distance,COMFORT_RADIUS))/(HEAT_RADIUS-COMFORT_RADIUS),0,1)
 return falloff*(BURNING_HEAT if state=="burning" else EMBER_HEAT)
static func step(wetness:float,seconds:float,air:float,heat:float,wind:float,rain:float,roof:bool,closed:bool,mine:bool) -> Dictionary:
 var minutes:=maxf(0,seconds)/60.0
 var gain:=RAIN_WETTING*clampf(rain,0,1) if not roof and not mine else 0.0
 var drying:=PASSIVE_DRYING+maxf(0,heat)*FIRE_DRYING
 var rate:=gain-drying
 var wet:=clampf(wetness,0,100)
 var end:=clampf(wet+minutes*rate,0,100)
 # Integrate wetness exactly, including early arrival at 0/100. Frame-rate
 # and accelerated sleep must not give different insulation over one step.
 var moving:=minf(minutes,absf((end-wet)/rate)) if not is_zero_approx(rate) else 0.0
 var mean:=((wet+end)*0.5*moving+end*(minutes-moving))/minutes if minutes>0 else wet
 var chill:=0.0 if roof or mine else clampf(wind,0,1)*3.0
 var felt:=air-mean*0.09+maxf(0,heat)-chill+(5.0 if closed else 0.0)
 if mine:felt=8.0-mean*0.04
 return {"wetness":end,"felt":felt,"heat":heat,"wind_chill":chill,"wet_rate":rate,"warmth_rate":(felt-NEUTRAL_FELT)*WARMTH_RESPONSE,"warmth_delta":minutes*(felt-NEUTRAL_FELT)*WARMTH_RESPONSE}
