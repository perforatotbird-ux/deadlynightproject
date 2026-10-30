"""Summarize benchmark JSON; pass a directory containing benchmark_before/after.json.
Requires pandas only for offline QA, never for game runtime.
"""
import hashlib,json,statistics,sys
from pathlib import Path
import pandas as pd
root=Path(sys.argv[1]); inputs={t:root/f'benchmark_{t}.json' for t in ('before','after')}
raw={t:json.loads(p.read_text()) for t,p in inputs.items()}
frames={t:pd.json_normalize(rows) for t,rows in raw.items()}
for tag,df in frames.items():
    assert len(df)==18 and df['ok'].all()
    assert set(df['count'])=={0,3,1000}
    assert all(df.groupby('count').size()==6)
metrics=[]
def metric(key,label,before,after,unit):
    metrics.append(dict(key=key,label=label,before=before,after=after,unit=unit))
def first(tag,n):return float(frames[tag].query('count==@n and iteration==0').iloc[0]['total_us'])/1000
def med(tag,n,col):
    value=float(frames[tag].query('count==@n and iteration>0')[col].median())
    independent=statistics.median(float(row['profile'][col[8:]]) if col.startswith('profile.') else float(row[col]) for row in raw[tag] if row['count']==n and row['iteration']>0)
    assert value==independent
    return value
metric('first','Первое сохранение, без изменённых деревьев',first('before',0),first('after',0),'ms')
metric('repeat','Повторная перезапись без изменений, медиана 5',med('before',0,'total_us')/1000,med('after',0,'total_us')/1000,'ms')
metric('small','Перезапись после 3 изменённых деревьев / 12 picked-ID',first('before',3),first('after',3),'ms')
metric('large','Перезапись после 1000 изменённых деревьев / 4000 picked-ID',first('before',1000),first('after',1000),'ms')
metric('large_repeat','Повторная перезапись большого состояния, медиана 5',med('before',1000,'total_us')/1000,med('after',1000,'total_us')/1000,'ms')
metric('bytes','Размер JSON большого состояния',med('before',1000,'profile.bytes'),med('after',1000,'profile.bytes'),'bytes')
metric('memory','Выборка прироста static-memory после сериализации, большой слот',med('before',1000,'profile.memory_delta'),med('after',1000,'profile.memory_delta'),'bytes')
for n,label in [(0,'малый'),(1000,'большой')]:
    metric(f'load_{n}',f'Тёплая загрузка: чтение + JSON + применение, {label} слот',*[float(frames[t].query('count==@n and iteration==5').iloc[0]['full_load_us'])/1000 for t in ('before','after')],'ms')
phases=[]
for key,label in [('player_us','Персонаж'),('voxel_us','Реестр изменений деревьев'),('items_us','Физические брёвна'),('world_us','Состояние survival / предметов / погоды'),('assemble_us','Header и сборка payload'),('serialize_us','JSON-сериализация'),('disk_us','Файл, проверка, backup и замена'),('metadata_us','Manifest')]:
    phases.append(dict(key=key,label=label,**{t:med(t,1000,'profile.'+key)/1000 for t in ('before','after')}))
evidence=dict(sources={t:{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'rows':len(raw[t])} for t,p in inputs.items()},baseline_commit='3501a69',measurement='Godot 4.7.2 Linux headless; same fixture scene and synthetic state; sequential, isolated XDG_DATA_HOME; microsecond clocks',comparison_plan='Table requested by engineering acceptance; one first write per scenario and median of five subsequent writes. No target GPU/FPS claims.',metrics=metrics,large_repeat_phases_ms=phases,notes=['File read+parse and synchronous state application measured together; cold scene construction not included.','OS static-memory sample after serialization, not process RSS high-water or guaranteed allocation peak.','Baseline fixture measures original save algorithm; distant synthetic tree records do not reconstruct 1000 nearby meshes.','Lower small-save latency was not achieved; backup verification intentionally adds overhead.'])
(root/'benchmark_summary.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2))
def fmt(v,unit):return f'{v:,.0f}'.replace(',',' ') if unit=='bytes' else f'{v:.3f}'
lines=['| Сценарий | До | После |','| --- | ---: | ---: |']
for m in metrics:lines.append(f'| {m["label"]} | {fmt(m["before"],m["unit"])} {m["unit"]} | {fmt(m["after"],m["unit"])} {m["unit"]} |')
lines+=['','Этапы большого повторного сохранения: медианы, мс.','', '| Этап | До | После |','| --- | ---: | ---: |']
for p in phases:lines.append(f'| {p["label"]} | {p["before"]:.3f} | {p["after"]:.3f} |')
(root/'benchmark_tables.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
