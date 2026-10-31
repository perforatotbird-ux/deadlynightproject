shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float opacity : hint_range(0.0,1.0) = 1.0;
uniform float life_time = 0.0;
uniform float wing_rate = 24.0;
uniform vec3 observer = vec3(0.0);
varying vec3 world_pos;
void vertex() {
 float phase = life_time * wing_rate + MODEL_MATRIX[3].x * 3.7 + MODEL_MATRIX[3].z;
 if(abs(VERTEX.x)>0.009){float a=sin(phase)*0.9;float side=sign(VERTEX.x);float reach=abs(VERTEX.x);VERTEX.x=cos(a)*reach*side;VERTEX.y+=sin(a)*reach;}
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){ALBEDO=COLOR.rgb;ROUGHNESS=0.9;ALPHA=opacity*smoothstep(0.5,1.3,distance(world_pos,observer));}
