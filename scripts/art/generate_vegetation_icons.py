from pathlib import Path
p=Path(__file__).resolve().parents[2]/'assets/ui/field_journal/icons'
styles={'krasnitsa':('#b4493c',0),'sizovka':('#6880a0',1),'bolotnitsa':('#d5a148',2),'forest_fat':('#bb8c51',3),'wood_fan':('#939b96',4),'copper_false':('#a45e36',5),'pale_bell':('#dad4b5',6),'stump_fan':('#be7947',4)}
for id,(color,shape) in styles.items():
 if shape<3:
  artwork='<path d="M30 58Q29 30 51 14M28 40Q8 28 9 18Q30 17 32 30M35 30Q56 30 60 18Q44 12 38 22" fill="#526b48" stroke="#a6ad82" stroke-width="2"/>'
  for x,y in [(22,38),(34,39),(28,48)]:
   artwork+=f'<ellipse cx="{x}" cy="{y}" rx="7" ry="{10 if shape==1 else 7}" fill="{color}" stroke="#dfcfa3" stroke-width="1.4"/>'
   if shape==2:artwork+=f'<path d="M{x-5} {y}h10M{x} {y-5}v10" stroke="#eed897" stroke-width="1"/>'
 elif shape==4:
  artwork='<path d="M21 58V15L28 10V58" fill="#645a48" stroke="#b2a47d" stroke-width="2"/>'
  for y in ([28,46] if id=='stump_fan' else [25,37,49]):artwork+=f'<path d="M22 {y}Q45 {y-16} 59 {y-1}Q47 {y+10} 22 {y+3}Z" fill="{color}" stroke="#e1cc9e" stroke-width="2"/>'
 else:
  artwork='<path d="M26 53L29 27H37L41 53Q34 60 26 53" fill="#c5b799" stroke="#efdfb8" stroke-width="2"/>'
  if shape==6:artwork+=f'<path d="M15 38L26 12Q31 4 37 12L49 38Q32 46 15 38Z" fill="{color}" stroke="#e6d4ad" stroke-width="2"/><path d="M18 39L30 29M26 41L32 29M37 41L34 29M46 39L36 29" stroke="#494534" stroke-width="2"/><ellipse cx="33" cy="54" rx="11" ry="6" fill="#d8cbb0"/>'
  else:artwork+=f'<path d="M9 31Q10 {3 if shape==3 else 14} 32 12Q55 {8 if shape==3 else 17} 56 31Q35 40 9 31Z" fill="{color}" stroke="#e4c99a" stroke-width="2"/>'
  if shape==5:artwork+='<path d="M22 42Q32 37 44 42L40 46H25Z" fill="#e6d8b5"/>'
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{artwork}</svg>'
 (p/f'{id}.svg').write_text(svg)
 if shape>=3 and id!='stump_fan':(p/f'cooked_{id}.svg').write_text(svg.replace('</svg>','<path d="M8 57H48M45 57L61 48" stroke="#ded4b4" stroke-width="4" stroke-linecap="round"/></svg>'))
extras={
'wood_tea':'<path d="M15 23H45V47Q30 60 15 47Z" fill="#79918b" stroke="#e0d5b5" stroke-width="2"/><path d="M45 27Q62 27 53 42H45M24 18Q19 12 26 6M36 18Q30 11 38 5" fill="none" stroke="#d8cba9" stroke-width="3"/><ellipse cx="30" cy="24" rx="14" ry="4" fill="#946b3c"/>',
'antitoxin':'<path d="M21 10H43V20L47 26V56H17V26L21 20Z" fill="#81958a" stroke="#dfd2ae" stroke-width="2"/><path d="M20 11H44V19H20Z" fill="#b8ac8b"/><path d="M28 29H36V36H43V44H36V51H28V44H21V36H28Z" fill="#e1d5b7"/>',
'field_notes':'<path d="M14 5H43L53 15V59H14Z" fill="#d0c3a1" stroke="#6c715b" stroke-width="2"/><path d="M21 22H45M21 29H43M21 46H45M21 52H39" stroke="#59664f" stroke-width="2"/><path d="M24 39Q31 27 40 39ZM31 39V45" fill="#977347" stroke="#59664f" stroke-width="2"/>'}
for id,art in extras.items():(p/f'{id}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{art}</svg>')
