shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
varying flat float view_index;
void vertex() {
 vec3 origin=MODEL_MATRIX[3].xyz;
 vec3 direction=normalize(vec3(CAMERA_POSITION_WORLD.x-origin.x,0.0,CAMERA_POSITION_WORLD.z-origin.z)+vec3(0.00001,0.0,0.0));
 vec3 original_right=normalize(MODEL_MATRIX[0].xyz+vec3(0.000001,0.0,0.0));
 vec3 original_back=normalize(MODEL_MATRIX[2].xyz+vec3(0.0,0.0,0.000001));
 float angle=atan(dot(direction,original_right),dot(direction,original_back));
 view_index=mod(floor(angle*8.0/6.28318530718+0.5)+8.0,8.0);
 float scale_value=length(MODEL_MATRIX[0].xyz);
 vec3 right=cross(vec3(0.0,1.0,0.0),direction);
 vec3 world=origin+(right*VERTEX.x+vec3(0.0,VERTEX.y,0.0))*scale_value;
 VERTEX=(VIEW_MATRIX*vec4(world,1.0)).xyz;
 NORMAL=normalize((VIEW_MATRIX*vec4(direction*0.85+vec3(0.0,0.5,0.0),0.0)).xyz);
}
void fragment() {
 vec2 tile_uv=clamp(UV,vec2(0.002),vec2(0.998));
 vec4 color=texture(atlas,vec2((tile_uv.x+view_index)/8.0,tile_uv.y));
 ALBEDO=color.rgb;ROUGHNESS=1.0;SPECULAR=0.0;
 ALPHA=color.a;ALPHA_SCISSOR_THRESHOLD=0.4;
}
