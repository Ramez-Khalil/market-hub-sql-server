#!/usr/bin/env python3
"""Generate model documentation and Graphviz diagrams from the checked-in DDL.
Requires Python 3 and Graphviz dot. Does not connect to a database.
"""
from pathlib import Path
import re, html, subprocess, json
ROOT=Path(__file__).resolve().parents[1]
sql=(ROOT/'sql/01_schema.sql').read_text()
D=ROOT/'docs'; OUT=D/'diagrams'; OUT.mkdir(parents=True,exist_ok=True)

def parts(text):
    result=[]; depth=0; quote=False; start=0
    for i,c in enumerate(text):
        if c=="'": quote=not quote
        if not quote:
            if c=='(':depth+=1
            elif c==')':depth-=1
            elif c==',' and depth==0: result.append(text[start:i].strip()); start=i+1
    result.append(text[start:].strip());return result

def body_after(start):
    depth=1;quote=False;i=start
    while depth:
        c=sql[i]
        if c=="'":quote=not quote
        if not quote:
            if c=='(':depth+=1
            elif c==')':depth-=1
        i+=1
    return sql[start:i-1]

tables={};fks=[]
for m in re.finditer(r'CREATE TABLE dbo\.(\w+)\s*\(',sql,re.I):
    name=m.group(1); body=body_after(m.end()); cols=[];pk=[];uq=[]
    for entry in parts(body):
        if entry.upper().startswith('CONSTRAINT'):
            p=re.search(r'PRIMARY KEY\s*\(([^)]+)\)',entry,re.I)
            if p:pk=[x.strip() for x in p.group(1).split(',')]
            u=re.search(r'UNIQUE\s*\(([^)]+)\)',entry,re.I)
            if u:uq.append([x.strip() for x in u.group(1).split(',')])
            f=re.search(r'CONSTRAINT\s+(\w+)\s+FOREIGN KEY\s*\(([^)]+)\)\s+REFERENCES dbo\.(\w+)\s*\(([^)]+)\)',entry,re.I)
            if f:fks.append(dict(child=name,name=f.group(1),cols=f.group(2),parent=f.group(3),refs=f.group(4)))
        else:
            c=re.match(r'(\w+)\s+([\w]+(?:\([^)]*\))?)\s*(.*)',entry,re.S)
            if not c:raise ValueError(entry)
            cn,typ,tail=c.groups(); computed=typ.upper()=='AS'; typ='computed expression' if computed else typ; col=dict(name=cn,type=typ,nullable=not bool(re.search(r'NOT NULL',tail,re.I)),tail=tail,computed=computed)
            cols.append(col)
            if 'PRIMARY KEY' in tail.upper():pk.append(cn)
            if re.search(r'\bUNIQUE\b',tail,re.I):uq.append([cn])
            f=re.search(r'CONSTRAINT\s+(\w+)\s+REFERENCES dbo\.(\w+)\s*\(([^)]+)\)',tail,re.I)
            if f:fks.append(dict(child=name,name=f.group(1),cols=cn,parent=f.group(2),refs=f.group(3)))
    tables[name]=dict(cols=cols,pk=pk,uq=uq)

fkcols={(f['child'],c.strip()) for f in fks for c in f['cols'].split(',')}
lines=['# Data dictionary','', 'Generated from [`sql/01_schema.sql`](../sql/01_schema.sql). All names and physical types below come from the DDL. Fictional seed records are used throughout.','']
for name,t in sorted(tables.items()):
    lines += ['## '+name,'','Primary key: `'+', '.join(t['pk'])+'`.']
    if t['uq']:lines += ['Additional unique keys: '+ '; '.join('`'+', '.join(k)+'`' for k in t['uq'])+'.']
    lines += ['','| Column | SQL Server type | Null allowed | Key |','|---|---|---|---|']
    for c in t['cols']:
        key=('PK ' if c['name'] in t['pk'] else '')+('FK' if (name,c['name']) in fkcols else '')
        lines.append(f"| {c['name']} | `{c['type']}` | {'Derived' if c.get('computed') else ('Yes' if c['nullable'] else 'No')} | {key.strip()} |")
    lines+=['']
lines+=['## Relationships','','All foreign keys use SQL Server’s default no-action behavior; referenced rows cannot be removed while dependent rows exist.','', '| Foreign key | Child columns | Referenced columns |','|---|---|---|']
for f in fks:lines.append(f"| `{f['name']}` | `{f['child']}({f['cols']})` | `{f['parent']}({f['refs']})` |")
lines+=['','For CHECK constraints, views, stored procedures and permissions, inspect the canonical DDL directly. This dictionary describes definitions, not a claim that an execution has passed.','']
(D/'data-dictionary.md').write_text('\n'.join(lines))

schema=['# Relational schema','','Relations are listed alphabetically. PK = primary key; FK = foreign key; UQ = additional unique key. See the [data dictionary](data-dictionary.md) for nullability and types.','']
for name,t in sorted(tables.items()):
    attrs=[]
    for c in t['cols']:
        flags=[]
        if c['name'] in t['pk']:flags+=['PK']
        if (name,c['name']) in fkcols:flags+=['FK']
        attrs.append(c['name']+(' ['+'/'.join(flags)+']' if flags else ''))
    schema+=['## '+name,'','`'+name+'('+', '.join(attrs)+')`','']
(D/'relational-schema.md').write_text('\n'.join(schema))

base='''digraph G {
 graph [bgcolor="#F8FAFC", pad="0.35", nodesep="0.45", ranksep="0.75", fontname="DejaVu Sans", fontsize=20, labelloc=t, labeljust=l];
 node [shape=plain, fontname="DejaVu Sans", fontsize=10];
 edge [fontname="DejaVu Sans", fontsize=9, color="#64748B", arrowsize=0.7];
'''
def render(name,title,body,rankdir='LR'):
    text=base+f' label="{title}"; rankdir={rankdir};\n'+body+'\n}\n'
    (OUT/(name+'.dot')).write_text(text)
    for fmt in ['svg','png']:
        subprocess.run(['dot','-T'+fmt,str(OUT/(name+'.dot')),'-o',str(OUT/(name+'.'+fmt))],check=True)

def box(name,rows):
    head=f'<TR><TD BGCOLOR="#0F2942" ALIGN="LEFT"><FONT COLOR="white"><B>{name}</B></FONT></TD></TR>'
    body=''.join('<TR><TD ALIGN="LEFT" BGCOLOR="'+('#E8F4F1' if i%2==0 else '#FFFFFF')+'">'+html.escape(r)+'</TD></TR>' for i,r in enumerate(rows))
    return f'{name} [label=<<TABLE BORDER="1" COLOR="#CBD5E1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="6">{head}{body}</TABLE>>];\n'
for mode in ['logical','physical','referential-integrity']:
    body=''
    for name,t in tables.items():
        rows=[]
        for c in t['cols']:
            pk=c['name'] in t['pk'];fk=(name,c['name']) in fkcols
            if mode=='referential-integrity' and not(pk or fk):continue
            label=('PK ' if pk else '')+('FK ' if fk else '')+c['name']
            if mode=='physical':label+=' : '+c['type']+(' (derived)' if c.get('computed') else (' NULL' if c['nullable'] else ' NOT NULL'))
            rows.append(label)
        body+=box(name,rows)
    for f in fks:body+=f"{f['parent']} -> {f['child']} [label=\"{f['refs']} → {f['cols']}\" headlabel=\"0..*\" taillabel=\"1\"];\n"
    render(mode,{'logical':'MARKETHUB / Logical model','physical':'MARKETHUB / SQL Server physical model','referential-integrity':'MARKETHUB / Foreign-key map'}[mode],body)

body='node [shape=box, style="rounded,filled", fillcolor="#E8F4F1", color="#79A89C", margin="0.18,0.12"];\n'
for n in ['REGION','STORE','VENDOR','PRODUCT_CATEGORY','PRODUCT','CUSTOMER','SALE']:body+=f'{n};\n'
for a,b,label in [('REGION','STORE','contains'),('VENDOR','PRODUCT','supplies'),('PRODUCT_CATEGORY','PRODUCT','classifies'),('STORE','SALE','records'),('CUSTOMER','SALE','places')]:body+=f'{a} -> {b} [label="{label}",taillabel="1",headlabel="0..*"];\n'
body+='STORE -> PRODUCT [dir=both, label="stocks / STORE_PRODUCT",taillabel="0..*",headlabel="0..*"];\nSALE -> PRODUCT [dir=both,label="includes / SALE_LINE",taillabel="0..*",headlabel="1..*"];\n'
render('conceptual','MARKETHUB / Business concepts',body)
body=box('PRODUCT',['ProductId · shared identity','ProductType = P or D','Total and disjoint classification'])+box('PERISHABLE_PRODUCT',['ProductType = P','ShelfLifeDays > 0','WarrantyMonths is NULL','SQL view over PRODUCT'])+box('DURABLE_PRODUCT',['ProductType = D','WarrantyMonths >= 0','ShelfLifeDays is NULL','SQL view over PRODUCT'])
body+='PRODUCT -> PERISHABLE_PRODUCT [label="P"]; PRODUCT -> DURABLE_PRODUCT [label="D"];'
render('specialization','MARKETHUB / Product specialization',body,'TB')
body=''
for name,t in sorted(tables.items()):
    nonkeys=[c['name'] for c in t['cols'] if c['name'] not in t['pk'] and not c.get('computed')]
    body+=box(name,['DETERMINANT: '+', '.join(t['pk']),'↓ full dependency']+nonkeys)
# Arrange the independent dependency boxes in a compact 3-by-3 reading order.
names=sorted(tables)
for i in range(0,len(names),3): body+='{rank=same; '+ '; '.join(names[i:i+3])+';}\n'
for i in range(len(names)-3): body+=names[i]+' -> '+names[i+3]+' [style=invis];\n'
render('functional-dependencies','MARKETHUB / Primary-key functional dependencies',body,'TB')
(OUT/'model.json').write_text(json.dumps(dict(tables=tables,foreign_keys=fks),indent=2))
print(f'Generated {len(tables)} tables, {len(fks)} foreign keys, six diagram sets and dictionary.')
