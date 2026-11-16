# Data dictionary

Generated from [`sql/01_schema.sql`](../sql/01_schema.sql). All names and physical types below come from the DDL. Fictional seed records are used throughout.

## CUSTOMER

Primary key: `CustomerId`.
Additional unique keys: `Email`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| CustomerId | `int` | No | PK |
| FirstName | `nvarchar(50)` | No |  |
| LastName | `nvarchar(50)` | No |  |
| CustomerName | `computed expression` | Derived |  |
| Phone | `varchar(25)` | Yes |  |
| StreetAddress | `nvarchar(150)` | Yes |  |
| City | `nvarchar(80)` | Yes |  |
| StateCode | `char(2)` | Yes |  |
| PostalCode | `varchar(10)` | Yes |  |
| Email | `nvarchar(254)` | No |  |

## PRODUCT

Primary key: `ProductId`.
Additional unique keys: `SKU`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| ProductId | `int` | No | PK |
| SKU | `varchar(30)` | No |  |
| ProductName | `nvarchar(120)` | No |  |
| Description | `nvarchar(250)` | Yes |  |
| VendorId | `int` | No | FK |
| CategoryId | `int` | No | FK |
| CurrentUnitPrice | `decimal(12,2)` | No |  |
| ProductType | `char(1)` | No |  |
| ShelfLifeDays | `int` | Yes |  |
| WarrantyMonths | `int` | Yes |  |

## PRODUCT_CATEGORY

Primary key: `CategoryId`.
Additional unique keys: `CategoryName`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| CategoryId | `int` | No | PK |
| CategoryName | `nvarchar(80)` | No |  |
| County | `nvarchar(80)` | Yes |  |

## REGION

Primary key: `RegionId`.
Additional unique keys: `RegionName`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| RegionId | `int` | No | PK |
| RegionName | `nvarchar(80)` | No |  |
| County | `nvarchar(80)` | Yes |  |
| Description | `nvarchar(250)` | Yes |  |

## SALE

Primary key: `SaleId`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| SaleId | `bigint` | No | PK |
| StoreId | `int` | No | FK |
| CustomerId | `int` | No | FK |
| SoldAt | `datetime2(0)` | No |  |
| Description | `nvarchar(250)` | Yes |  |

## SALE_LINE

Primary key: `SaleId, ProductId`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| SaleId | `bigint` | No | PK FK |
| ProductId | `int` | No | PK FK |
| Quantity | `int` | No |  |
| UnitPriceAtSale | `decimal(12,2)` | No |  |

## STORE

Primary key: `StoreId`.
Additional unique keys: `StoreName`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| StoreId | `int` | No | PK |
| RegionId | `int` | No | FK |
| StoreName | `nvarchar(100)` | No |  |
| City | `nvarchar(80)` | No |  |
| StreetAddress | `nvarchar(150)` | Yes |  |
| StateCode | `char(2)` | Yes |  |
| PostalCode | `varchar(10)` | Yes |  |
| ManagerName | `nvarchar(100)` | Yes |  |
| Phone | `varchar(25)` | Yes |  |
| OpeningHours | `nvarchar(150)` | Yes |  |

## STORE_PRODUCT

Primary key: `StoreId, ProductId`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| StoreId | `int` | No | PK FK |
| ProductId | `int` | No | PK FK |
| StockQuantity | `int` | No |  |
| ReorderLevel | `int` | No |  |

## VENDOR

Primary key: `VendorId`.
Additional unique keys: `VendorName`.

| Column | SQL Server type | Null allowed | Key |
|---|---|---|---|
| VendorId | `int` | No | PK |
| VendorName | `nvarchar(100)` | No |  |
| ContactName | `nvarchar(100)` | Yes |  |
| Email | `nvarchar(254)` | Yes |  |
| Phone | `varchar(25)` | Yes |  |
| StreetAddress | `nvarchar(150)` | Yes |  |
| City | `nvarchar(80)` | Yes |  |
| StateCode | `char(2)` | Yes |  |
| PostalCode | `varchar(10)` | Yes |  |

## Relationships

All foreign keys use SQL Server’s default no-action behavior; referenced rows cannot be removed while dependent rows exist.

| Foreign key | Child columns | Referenced columns |
|---|---|---|
| `FK_STORE_REGION` | `STORE(RegionId)` | `REGION(RegionId)` |
| `FK_PRODUCT_VENDOR` | `PRODUCT(VendorId)` | `VENDOR(VendorId)` |
| `FK_PRODUCT_CATEGORY` | `PRODUCT(CategoryId)` | `PRODUCT_CATEGORY(CategoryId)` |
| `FK_STORE_PRODUCT_STORE` | `STORE_PRODUCT(StoreId)` | `STORE(StoreId)` |
| `FK_STORE_PRODUCT_PRODUCT` | `STORE_PRODUCT(ProductId)` | `PRODUCT(ProductId)` |
| `FK_SALE_STORE` | `SALE(StoreId)` | `STORE(StoreId)` |
| `FK_SALE_CUSTOMER` | `SALE(CustomerId)` | `CUSTOMER(CustomerId)` |
| `FK_SALE_LINE_SALE` | `SALE_LINE(SaleId)` | `SALE(SaleId)` |
| `FK_SALE_LINE_PRODUCT` | `SALE_LINE(ProductId)` | `PRODUCT(ProductId)` |

For CHECK constraints, views, stored procedures and permissions, inspect the canonical DDL directly. This dictionary describes definitions, not a claim that an execution has passed.
