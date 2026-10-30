shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_never;
uniform vec3 roof_min=vec3(0);
uniform vec3 roof_max=vec3(0);
uniform bool roof_enabled=false;
uniform float opacity=0.3;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 if(roof_enabled && world_pos.x>roof_min.x && world_pos.x<roof_max.x && world_pos.z>roof_min.z && world_pos.z<roof_max.z && world_pos.y<roof_max.y && world_pos.y>roof_min.y){discard;}
 float edge=sin(UV.x*3.14159)*sin(UV.y*3.14159);
 ALBEDO=vec3(0.36,0.43,0.49);ROUGHNESS=1.0;SPECULAR=0.0;ALPHA=edge*opacity;
}
