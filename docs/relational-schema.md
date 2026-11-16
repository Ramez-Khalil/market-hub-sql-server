# Relational schema

Relations are listed alphabetically. PK = primary key; FK = foreign key; UQ = additional unique key. See the [data dictionary](data-dictionary.md) for nullability and types.

## CUSTOMER

`CUSTOMER(CustomerId [PK], FirstName, LastName, CustomerName, Phone, StreetAddress, City, StateCode, PostalCode, Email)`

## PRODUCT

`PRODUCT(ProductId [PK], SKU, ProductName, Description, VendorId [FK], CategoryId [FK], CurrentUnitPrice, ProductType, ShelfLifeDays, WarrantyMonths)`

## PRODUCT_CATEGORY

`PRODUCT_CATEGORY(CategoryId [PK], CategoryName, County)`

## REGION

`REGION(RegionId [PK], RegionName, County, Description)`

## SALE

`SALE(SaleId [PK], StoreId [FK], CustomerId [FK], SoldAt, Description)`

## SALE_LINE

`SALE_LINE(SaleId [PK/FK], ProductId [PK/FK], Quantity, UnitPriceAtSale)`

## STORE

`STORE(StoreId [PK], RegionId [FK], StoreName, City, StreetAddress, StateCode, PostalCode, ManagerName, Phone, OpeningHours)`

## STORE_PRODUCT

`STORE_PRODUCT(StoreId [PK/FK], ProductId [PK/FK], StockQuantity, ReorderLevel)`

## VENDOR

`VENDOR(VendorId [PK], VendorName, ContactName, Email, Phone, StreetAddress, City, StateCode, PostalCode)`
