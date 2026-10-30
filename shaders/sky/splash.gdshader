shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_never;
uniform float opacity=0.14;
void fragment(){
 float a=exp(-dot(UV-vec2(0.3,0.55),UV-vec2(0.3,0.55))*450.0);
 float b=exp(-dot(UV-vec2(0.55,0.25),UV-vec2(0.55,0.25))*550.0);
 float c=exp(-dot(UV-vec2(0.75,0.65),UV-vec2(0.75,0.65))*500.0);
 ALBEDO=vec3(0.35,0.43,0.48);ALPHA=min(1.0,a+b+c)*opacity;
 ROUGHNESS=1.0;SPECULAR=0.0;
}
