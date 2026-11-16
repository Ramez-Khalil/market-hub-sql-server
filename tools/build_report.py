#!/usr/bin/env python3
"""Build the project report from the canonical model and recorded SQL evidence."""
from pathlib import Path
import json,html
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,PageBreak,Image,Table,TableStyle,KeepTogether
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
pdfmetrics.registerFont(TTFont("ReportSans", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("ReportSans-Bold", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"))
pdfmetrics.registerFontFamily("ReportSans",normal="ReportSans",bold="ReportSans-Bold",italic="ReportSans",boldItalic="ReportSans-Bold")
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import landscape,letter
from PIL import Image as PILImage
R=Path(__file__).resolve().parents[1]; D=R/'docs'; M=json.loads((D/'diagrams/model.json').read_text())
styles=getSampleStyleSheet();styles.add(ParagraphStyle(name='BodyX',fontName='ReportSans',fontSize=10,leading=14,spaceAfter=8,textColor=colors.HexColor('#24384A')))
styles.add(ParagraphStyle(name='SmallX',parent=styles['BodyX'],fontSize=8,leading=10,spaceAfter=4))
styles.add(ParagraphStyle(name='TitleX',fontName='ReportSans-Bold',fontSize=34,leading=40,textColor=colors.HexColor('#12344A'),spaceAfter=18))
styles.add(ParagraphStyle(name='HeadX',fontName='ReportSans-Bold',fontSize=21,leading=26,textColor=colors.HexColor('#12344A'),spaceAfter=13))
styles.add(ParagraphStyle(name='SubX',fontName='ReportSans-Bold',fontSize=12,leading=15,spaceAfter=8,textColor=colors.HexColor('#167666')))
S=[]
def p(text,style='BodyX'):return Paragraph(text,styles[style])
def para(t):S.append(p(t))
def head(t):S.append(p(t,'HeadX'))
def sub(t):S.append(p(t,'SubX'))
def page(t):S.append(PageBreak());head(t)
def pic(name,maxh=360):
    path=D/'diagrams'/f'{name}.png';w,h=PILImage.open(path).size;scale=min(684/w,maxh/h)
    S.append(Image(str(path),w*scale,h*scale));S.append(Spacer(1,8))
def table(rows,widths,header=True,compact=False):
    cell=[[p(html.escape(str(x)),'SmallX') for x in row] for row in rows]
    t=Table(cell,colWidths=widths,repeatRows=1 if header else 0,hAlign='LEFT');spec=[('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),1.5 if compact else 5),('BOTTOMPADDING',(0,0),(-1,-1),1.5 if compact else 5),('LINEBELOW',(0,0),(-1,0),1,colors.HexColor('#167666')),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.HexColor('#F0F6F5'),colors.white])]
    if header:spec += [('BACKGROUND',(0,0),(-1,0),colors.HexColor('#D9E8EC'))]
    t.setStyle(TableStyle(spec));S.append(t);S.append(Spacer(1,2 if compact else 8))
S.extend([Spacer(1,60),p('MarketHubDB','TitleX'),p('Retail database design, implementation and validation','HeadX'),Spacer(1,14),p('Ramez Khalil','SubX'),p('Microsoft SQL Server | Relational modeling | Inventory and sales reporting'),Spacer(1,30)])
para('A multi-store retail model that connects products, suppliers, inventory and customer purchases. The implementation records a sale, preserves its historical prices, updates stock and turns the resulting records into business reports.')
para('Portfolio edition. Independently rebuilt from an academic retail scenario using fictional data. No real client records or private course documents are included.')
page('Contents')
contents=[['Section','Report page'],['1. Purpose and business rules','2'],['2. Conceptual model','3'],['3. Logical model','4'],['4. Physical data dictionary: customers and products','5'],['5. Physical data dictionary: stores and vendors','6'],['6. Physical data dictionary: remaining relations','7'],['7. Product specialization','8'],['8. Referential integrity','9'],['9. Dependencies and normalization','10'],['10. SQL Server results and validation','11'],['11. Reproduction, scope and references','12']]
table(contents,[570,114])
page('1. Purpose and business rules')
para('The retailer needs a consistent answer to four questions: what does each store carry, how much is in stock, what did each customer purchase, and where are sales coming from? Nine related tables separate these facts without copying vendor or customer details into each transaction.')
table([['Business rule','Implementation'],['A store belongs to one region; a product to one vendor and category.','Required foreign keys protect the relationships.'],['A sale belongs to one customer and store.','SALE contains the receipt header; SALE_LINE contains its products.'],['A product can be stocked in several stores.','STORE_PRODUCT uses the (StoreId, ProductId) key.'],['Sales cannot use empty baskets, unavailable products or insufficient stock.','RecordSale validates the basket and writes the sale and stock movements in one transaction.'],['A changed catalog price must not change old receipts.','SALE_LINE stores UnitPriceAtSale separately from PRODUCT.CurrentUnitPrice.'],['Product categories need different descriptive attributes.','A total/disjoint perishable-or-durable rule selects shelf life or warranty.']],[335,349])
para('Master records can exist before their first child row. The sales workflow requires one or more sale lines. This lifecycle distinction is documented rather than pretending a foreign key can enforce parent minimum cardinality.')
page('2. Conceptual model')
pic('conceptual',330)
para('Entities describe business concepts before physical storage details. The many-to-many store/product and sale/product relationships become associative tables in the logical model. Each sale created by the supported procedure includes at least one product.')
para('Diagram cardinalities use 0..* for optional master-record participation and 1 for a required parent. The company can register a customer before that customer purchases anything.')
page('3. Logical model')
pic('referential-integrity',310)
para('This key-level view emphasizes how the nine relations connect. Full attributes are listed on the following pages and in the generated logical model asset. Composite keys prevent duplicate products within a sale and duplicate inventory rows for a store.')
para('The complete logical model is supplied in <b>docs/diagrams/logical.svg</b>; the alphabetized schema is in <b>docs/relational-schema.md</b>. Diagrams and column definitions are generated from the same SQL source.')
fk={(f['child'],c.strip()) for f in M['foreign_keys'] for c in f['cols'].split(',')}
def dict_tables(names):
 for name in names:
    sub(name);t=M['tables'][name];rows=[['Column','SQL Server type','Nullability / keys']]
    for c in t['cols']:
       notes=['Derived' if c.get('computed') else ('NULL' if c['nullable'] else 'NOT NULL')]
       if c['name'] in t['pk']:notes+=['PK']
       if (name,c['name']) in fk:notes+=['FK']
       if [c['name']] in t['uq']:notes+=['UQ']
       rows.append([c['name'],c['type'],', '.join(notes)])
    table(rows,[230,230,224],compact=True)
page('4. Physical dictionary: customers and products')
dict_tables(['CUSTOMER','PRODUCT'])
page('5. Physical dictionary: stores and vendors')
dict_tables(['STORE','VENDOR'])
page('6. Physical dictionary: remaining relations')
dict_tables(['PRODUCT_CATEGORY','REGION','SALE','SALE_LINE','STORE_PRODUCT'])
page('7. Product specialization')
pic('specialization',300)
para('The conceptual supertype is PRODUCT. Every product must be either perishable (P) or durable (D), never both. Perishable products require positive ShelfLifeDays and no WarrantyMonths. Durable products require nonnegative WarrantyMonths and no ShelfLifeDays.')
para('Single-table inheritance implements this rule with CK_PRODUCT_Subtype. PERISHABLE_PRODUCT and DURABLE_PRODUCT are filtered views, not stored child tables. The subtype test cases reject invalid classifications, overlapping attributes and missing required subtype data. Shelf life is descriptive; inventory-lot expiration is outside scope.')
page('8. Referential integrity')
rows=[['Child relation and columns','Parent relation and columns']]
for f in M['foreign_keys']:rows.append([f["child"]+'('+f['cols']+')',f['parent']+'('+f['refs']+')'])
table(rows,[342,342])
para('All nine foreign keys use default no-action behavior. A referenced row cannot be removed while dependent rows remain. NOT NULL foreign keys prevent a stored child row from omitting its required parent.')
para('RecordSale separately validates inventory membership and stock before recording the receipt. The MarketHubSalesClerk role is granted procedure execution but denied direct sales and inventory writes. No application login is created, and elevated administrators remain outside that role restriction.')
para('The complete connection diagram is supplied as docs/diagrams/referential-integrity.svg. The physical model with exact column types is docs/diagrams/physical.svg; the preceding dictionary keeps those definitions readable in this report.')
page('9. Dependencies and normalization')
rows=[['Relation','Determinant','Dependent stored facts']]
for name,t in sorted(M['tables'].items()):
    vals=[c['name'] for c in t['cols'] if c['name'] not in t['pk'] and not c.get('computed')]
    rows.append([name,', '.join(t['pk']),', '.join(vals)])
table(rows,[135,145,404])
para('<b>1NF:</b> repeating items are rows, not repeated columns. <b>2NF:</b> inventory quantities depend on both store and product; sale-line quantities and historical prices depend on both sale and product. <b>3NF:</b> vendor, category, region and customer descriptions remain in their own relations rather than being repeated beside foreign keys.')
para('CustomerName is computed, not an independently stored fact. Alternative candidate keys include SKU, customer Email and the explicitly unique region/store/vendor/category names. See docs/normalization.md for assumptions and the full dependency analysis.')
page('10. SQL Server results and validation')
para('Executed on Microsoft SQL Server 2025 Standard Developer, engine 17.0.1000.7, using a fresh isolated MarketHubPortfolio database. All five SQL scripts completed successfully. The test log ends with <b>ALL TESTS PASSED</b>.')
table([['Verified fixture','Result'],['Sales / sale lines / units','6 / 12 / 27'],['Total revenue from fictional seed data','$262.00'],['Harbor Market / River Market / Meadow Market','$133.50 / $74.00 / $54.50'],['Expected-error cases','19 rejected invalid operations'],['Positive checks','Seed totals, stock, subtype partition, historical prices, successful basket and rollback']],[300,384])
para('The reports return revenue by store, monthly sales and basket value, product demand, inventory replenishment and repeat-customer activity. Each number above comes from the synthetic scenario, not actual business performance.')
para('Verification files: evidence/sql-server/00_create_database.txt through 04_tests.txt. The runtime suite checks both rejected input and successful operations; full logs accompany the project. Multi-session contention and production-scale performance have not been benchmarked.')
page('11. Reproduction, scope and references')
para('Run sql/00_create_database.sql, 01_schema.sql, 02_seed.sql, 03_reports.sql and 04_tests.sql in order on an isolated SQL Server instance. The creation script refuses to replace an existing database. A Windows integrated-authentication runner is supplied as run.ps1.')
para('The repository includes editable Graphviz sources and rendered SVG/PNG models, not native ERwin files. This report is a project document, not a signed academic submission. No signature or instructor endorsement is implied.')
sub('Design references')
for title,url in [('Microsoft Learn: Primary and foreign key constraints','https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints'),('Microsoft Support: Database design basics','https://support.microsoft.com/en-us/access/database-design-basics'),('Microsoft Learn: CREATE TABLE (Transact-SQL)','https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql'),('Microsoft Learn: SET XACT_ABORT','https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql')]:
 para(f'<link href="{url}" color="#167666">{html.escape(title)}</link>')
sub('Conclusion')
para('MarketHubDB demonstrates how modeling choices become enforced database behavior: related records remain consistent, historical prices are preserved, and a sales workflow updates inventory atomically. Reproducible scripts, original diagrams and recorded SQL output make the result inspectable and teachable.')

def footer(c,doc):
 if doc.page>1:
  c.setStrokeColor(colors.HexColor('#CDDDE1'));c.line(54,37,738,37);c.setFont('ReportSans',8);c.setFillColor(colors.HexColor('#526779'));c.drawString(54,24,'MARKETHUBDB  |  PROJECT REPORT');c.drawRightString(738,24,str(doc.page-1))
doc=SimpleDocTemplate(str(D/'MarketHubDB_Project_Report.pdf'),pagesize=landscape(letter),rightMargin=54,leftMargin=54,topMargin=42,bottomMargin=48,title='MarketHubDB - Retail Database Project',author='Ramez Khalil')
doc.build(S,onFirstPage=footer,onLaterPages=footer)
print(D/'MarketHubDB_Project_Report.pdf')
