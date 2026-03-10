#!/usr/bin/env python3
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]

def parse_list(v: str):
    v=v.strip()
    if v.startswith('[') and v.endswith(']'):
        inner=v[1:-1].strip()
        if not inner: return []
        return [x.strip() for x in inner.split(',') if x.strip()]
    return []

def parse_fm(path: Path):
    t=path.read_text(encoding='utf-8')
    if not t.startswith('---\n'):
        return None
    end=t.find('\n---\n',4)
    if end==-1:
        return None
    out={}
    tr={}
    for ln in t[4:end].splitlines():
        if not ln.strip():
            continue
        if ln.startswith('  ') and ':' in ln:
            k,v=ln.strip().split(':',1)
            tr[k.strip()]=parse_list(v)
        elif ':' in ln:
            k,v=ln.split(':',1)
            out[k.strip()]=v.strip()
    if tr:
        out['Traceability']=tr
    return out

l0txt=(ROOT/'specs/product/l0/L0-feature-catalog.md').read_text()+"\n"+(ROOT/'specs/product/l0/L0-constraint-catalog.md').read_text()
l0_ids=sorted(set(re.findall(r'\*\*(F-[A-Z0-9-]+|C-[A-Z0-9-]+):\*\*', l0txt)))

l1=[]
for p in [*(ROOT/'specs/product/extracted').glob('*.md'), *(ROOT/'specs/product/adapted').glob('*.md'), *(ROOT/'specs/product/l1').glob('*/*.md')]:
    if p.name in ('README.md','TEMPLATE.md'):
        continue
    fm=parse_fm(p)
    if fm and fm.get('Layer')=='L1':
        l1.append((p,fm))

l2=[]
for p in (ROOT/'tests/specs').glob('*.md'):
    fm=parse_fm(p)
    if fm and fm.get('Layer')=='L2':
        l2.append((p,fm))

errors=[]
warnings=[]
id_index={}

l1_ids=set()
l0_to_l1={i:set() for i in l0_ids}
for p,fm in l1:
    sid=fm.get('Spec ID')
    if not sid:
        errors.append(f'L1 missing Spec ID: {p}')
        continue
    if sid in id_index:
        errors.append(f'Duplicate Spec ID {sid}: {id_index[sid]} and {p}')
    id_index[sid]=p
    l1_ids.add(sid)
    l0=(fm.get('Traceability') or {}).get('L0',[])
    if not l0:
        errors.append(f'L1 missing L0 refs: {sid}')
    for i in l0:
        if i in l0_to_l1: l0_to_l1[i].add(sid)
        else: warnings.append(f'L1 {sid} references unknown L0 ID: {i}')

for p,fm in l2:
    sid=fm.get('Spec ID') or str(p)
    if sid in id_index:
        errors.append(f'Duplicate Spec ID {sid}: {id_index[sid]} and {p}')
    id_index[sid]=p
    tr=fm.get('Traceability') or {}
    l1r=tr.get('L1',[])
    l0r=tr.get('L0',[])
    if not l1r:
        errors.append(f'L2 missing L1 refs: {sid}')
    if not l0r:
        errors.append(f'L2 missing L0 refs: {sid}')
    for lid in l1r:
        if lid not in l1_ids:
            errors.append(f'L2 {sid} references unknown L1 ID: {lid}')

orph_l0=[i for i,s in l0_to_l1.items() if not s]
for i in orph_l0:
    warnings.append(f'Orphaned L0 (no downstream L1): {i}')

l1_to_l2={i:set() for i in l1_ids}
for p,fm in l2:
    sid=fm.get('Spec ID')
    for lid in (fm.get('Traceability') or {}).get('L1',[]):
        if lid in l1_to_l2:
            l1_to_l2[lid].add(sid)
orph_l1=[i for i,s in l1_to_l2.items() if not s]
for i in orph_l1:
    warnings.append(f'Orphaned L1 (no downstream L2): {i}')

print(f'L0={len(l0_ids)} L1={len(l1)} L2={len(l2)}')
for w in warnings:
    print('WARN:',w)
for e in errors:
    print('ERROR:',e)

sys.exit(1 if errors else 0)
