shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform float opacity=0.18;
void fragment(){float r=length(UV-vec2(0.5))*2.0;float ring=exp(-pow((r-0.55)*12.0,2.0));ALBEDO=vec3(0.35,0.43,0.48);ALPHA=ring*opacity;ROUGHNESS=0.8;}
