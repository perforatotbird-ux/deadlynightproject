shader_type sky;
render_mode disable_fog;
uniform samplerCube stars : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D milky_way : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moon_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 sun_dir=vec3(0,1,0);
uniform vec3 moon_dir=vec3(0,0.5,0.866);
uniform vec3 pole=vec3(0,0.67,-0.74);
uniform vec3 meridian=vec3(0,0.74,0.67);
uniform float angle=0.0;
uniform float day=0.0;
uniform float cloud_cover=0.12;
uniform float world_seconds=0.0;
uniform float flash=0.0;
uniform int quality=1;
uniform vec3 meteor_start=vec3(0,1,0);
uniform vec3 meteor_end=vec3(0,1,0);
uniform float meteor_age=-1.0;
uniform float meteor_duration=0.7;
uniform vec3 anomaly_dir=vec3(0,-1,0);
uniform float anomaly_strength=0.0;
uniform vec3 anomaly_color=vec3(0.35,0.65,0.75);
uniform vec3 bolt_points[9];
uniform float bolt_strength=0.0;
uniform vec3 branch_points[5];
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float n=noise2(p)*0.57;n+=noise2(p*2.07+19.3)*0.28;if(quality>0){n+=noise2(p*4.19+3.7)*0.11;n+=noise2(p*8.3)*0.04;if(quality>1){n=mix(n,noise2(p*16.7),0.025);}}return n;}
float segment_distance(vec3 p,vec3 a,vec3 b){vec3 ab=b-a;float t=clamp(dot(p-a,ab)/max(dot(ab,ab),0.0000001),0.0,1.0);return length(p-(a+t*ab));}
void sky(){
 vec3 d=normalize(EYEDIR);
 vec3 zenith=mix(vec3(0.012,0.024,0.052),vec3(0.16,0.36,0.64),day);
 vec3 horizon=mix(vec3(0.042,0.059,0.095),vec3(0.58,0.68,0.76),day);
 float horizon_weight=pow(1.0-max(d.y,0.0),3.5);
 vec3 base=mix(zenith,horizon,horizon_weight);
 float sunset=(1.0-smoothstep(0.04,0.4,abs(sun_dir.y)))*smoothstep(-0.2,0.05,sun_dir.y);
 base+=vec3(0.38,0.12,0.035)*sunset*pow(max(dot(d,normalize(vec3(sun_dir.x,0.05,sun_dir.z))),0.0),7.0)*horizon_weight;
 if(AT_CUBEMAP_PASS){COLOR=mix(zenith,horizon,0.35);} else {
 // Continuous inverse celestial rotation: independent of camera, no TIME uniform.
 vec3 q=vec3(dot(d,vec3(1,0,0)),dot(d,meridian),dot(d,pole));
 vec3 eq=vec3(cos(angle)*q.x+sin(angle)*q.y,-sin(angle)*q.x+cos(angle)*q.y,q.z);
 vec2 uv=vec2(atan(eq.y,eq.x)/6.2831853+0.5,acos(clamp(eq.z,-1.0,1.0))/3.14159265);
 float dark=1.0-smoothstep(0.02,0.42,day);
 float haze=smoothstep(-0.01,0.25,d.y);
 float lunar_glare=1.0-0.75*pow(max(dot(d,moon_dir),0.0),180.0);
 vec3 st=texture(stars,normalize(eq)).rgb;
 float twinkle=0.94+0.06*sin(world_seconds*0.011+hash(floor(uv*vec2(2048,1024)))*80.0);
 vec3 celestial=(st*0.8*twinkle+texture(milky_way,uv).rgb*0.095)*dark*haze*lunar_glare;
 vec3 right=normalize(cross(vec3(0,1,0),moon_dir));vec3 up=normalize(cross(moon_dir,right));
 float radius=0.008;
 vec2 disk=vec2(dot(d,right),dot(d,up))/radius;
 float r2=dot(disk,disk);float mask=(1.0-smoothstep(0.95,1.02,r2))*step(0.0,dot(d,moon_dir));
 vec3 normal=right*disk.x+up*disk.y-moon_dir*sqrt(max(0.0,1.0-r2));
 float lit=smoothstep(-0.06,0.08,dot(normal,sun_dir));
 vec3 moon=texture(moon_map,disk*0.5+0.5).rgb*mix(vec3(0.9,0.67,0.4),vec3(0.76,0.84,1.0),smoothstep(0.0,0.3,moon_dir.y));
 celestial=mix(celestial,moon*(0.008+lit*1.0)*(1.0-day*0.75),mask*smoothstep(-0.02,0.015,d.y));
 float halo=pow(max(dot(d,moon_dir),0.0),1200.0)*(0.012+0.02*lit)*dark;
 celestial+=vec3(0.48,0.62,0.84)*halo;
 float sun_disk=smoothstep(cos(0.005),cos(0.0038),dot(d,sun_dir));
 base+=vec3(1.0,0.8,0.54)*sun_disk*2.0;
 if(meteor_age>=0.0 && meteor_age<meteor_duration){
  float t=meteor_age/meteor_duration;vec3 head=normalize(mix(meteor_start,meteor_end,t));vec3 tail=normalize(mix(meteor_start,meteor_end,max(0.0,t-0.3)));
  float dist=segment_distance(d,tail,head);float fade=sin(3.14159*t);
  celestial+=vec3(0.66,0.77,0.88)*exp(-dist*dist/0.0000005)*fade*dark*haze*1.15;
 }
 celestial+=anomaly_color*exp(-pow(length(d-anomaly_dir)/0.001,2.0))*anomaly_strength*dark*haze;
 vec2 p=d.xz/max(0.12,d.y+0.18);
 vec2 wind=vec2(world_seconds*0.000015,world_seconds*0.000011);
 vec2 warp=vec2(noise2(p*1.7+wind),noise2(p*1.7+17.2+wind))*0.7;
 float n=fbm(p*2.3+wind+warp);float high=quality>0?fbm(p*3.2-wind*0.3):0.0;
 float cloud=smoothstep(1.0-cloud_cover,1.17-cloud_cover,n)*smoothstep(-0.06,0.12,d.y);
 cloud=max(cloud,high*0.09*cloud_cover*smoothstep(0.0,0.3,d.y));
 vec3 cc=mix(vec3(0.025,0.033,0.048),vec3(0.43,0.49,0.54),day)*(0.6+0.4*n);
 cc+=vec3(0.3,0.11,0.04)*sunset*max(dot(d,sun_dir),0.0);
 cc+=vec3(0.22,0.29,0.39)*flash;
 base=mix(base+celestial,cc,cloud*0.97);
 base+=vec3(0.09,0.12,0.17)*flash;
 if(bolt_strength>0.0001){
 for(int i=0;i<8;i++){
  float dist=segment_distance(d,bolt_points[i],bolt_points[i+1]);
  base+=vec3(0.52,0.65,0.9)*exp(-dist*dist/0.0000005)*bolt_strength;
 }
 for(int i=0;i<4;i++){float dist=segment_distance(d,branch_points[i],branch_points[i+1]);base+=vec3(0.4,0.52,0.8)*exp(-dist*dist/0.00000015)*bolt_strength*0.5;}
 }
 base=mix(vec3(0.003,0.005,0.008),base,smoothstep(-0.05,0.0,d.y));
 COLOR=base;
 }
}
