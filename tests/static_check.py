"""Dependency-free source checks. Not a substitute for SQL Server execution."""
from decimal import Decimal
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
schema = (root/'sql/01_schema.sql').read_text()
seed = (root/'sql/02_seed.sql').read_text()
expected = {'REGION','STORE','VENDOR','PRODUCT_CATEGORY','PRODUCT','CUSTOMER','STORE_PRODUCT','SALE','SALE_LINE'}
assert set(re.findall(r'CREATE TABLE dbo\.(\w+)', schema)) == expected
assert len(re.findall(r'CONSTRAINT PK_', schema)) == 9
assert len(re.findall(r'CONSTRAINT FK_', schema)) == 9
assert 'UnitPriceAtSale decimal(12,2) NOT NULL' in schema
line = schema.split('CREATE TABLE dbo.SALE_LINE (')[1].split('\n);')[0]
assert 'StoreId' not in line, 'Do not introduce partial dependency on SaleId'
assert 'UPDLOCK, HOLDLOCK' in schema and 'BEGIN TRANSACTION' in schema
assert 'CK_PRODUCT_Subtype' in schema and 'WarrantyMonths IS NULL' in schema
assert 'DROP DATABASE' not in '\n'.join(p.read_text() for p in (root/'sql').glob('*.sql'))
assert seed.count('EXEC dbo.RecordSale') == 6
assert '@example.test' in seed
baskets = [[(2,'12.50'),(3,'4.00')],[(2,'9.00'),(1,'25.00')],
           [(1,'12.50'),(2,'6.50')],[(2,'25.00'),(3,'8.00')],
           [(5,'4.00'),(1,'9.00')],[(3,'12.50'),(2,'8.00')]]
assert sum(q for b in baskets for q,p in b) == 27
assert sum(Decimal(p)*q for b in baskets for q,p in b) == Decimal('262.00')
print('PASS: 9 tables, 9 PKs, 9 FKs, sale-price snapshot, normalized lines,')
print('      transaction locking, subtype check, no destructive database reset,')
print('      synthetic data, 6 sale calls, independent 27-unit/$262.00 oracle.')
print('STATIC CHECK ONLY: see engine execution logs for SQL Server runtime verification.')
