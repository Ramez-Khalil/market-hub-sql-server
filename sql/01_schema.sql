USE MarketHubPortfolio;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
CREATE TABLE dbo.REGION (
 RegionId int NOT NULL CONSTRAINT PK_REGION PRIMARY KEY,
 RegionName nvarchar(80) NOT NULL CONSTRAINT UQ_REGION_Name UNIQUE,
 County nvarchar(80) NULL,
 Description nvarchar(250) NULL
);
CREATE TABLE dbo.STORE (
 StoreId int NOT NULL CONSTRAINT PK_STORE PRIMARY KEY,
 RegionId int NOT NULL CONSTRAINT FK_STORE_REGION REFERENCES dbo.REGION(RegionId),
 StoreName nvarchar(100) NOT NULL CONSTRAINT UQ_STORE_Name UNIQUE,
 City nvarchar(80) NOT NULL,
 StreetAddress nvarchar(150) NULL, StateCode char(2) NULL, PostalCode varchar(10) NULL,
 ManagerName nvarchar(100) NULL, Phone varchar(25) NULL, OpeningHours nvarchar(150) NULL
);
CREATE TABLE dbo.VENDOR (
 VendorId int NOT NULL CONSTRAINT PK_VENDOR PRIMARY KEY,
 VendorName nvarchar(100) NOT NULL CONSTRAINT UQ_VENDOR_Name UNIQUE,
 ContactName nvarchar(100) NULL, Email nvarchar(254) NULL, Phone varchar(25) NULL,
 StreetAddress nvarchar(150) NULL, City nvarchar(80) NULL, StateCode char(2) NULL, PostalCode varchar(10) NULL
);
CREATE TABLE dbo.PRODUCT_CATEGORY (
 CategoryId int NOT NULL CONSTRAINT PK_PRODUCT_CATEGORY PRIMARY KEY,
 CategoryName nvarchar(80) NOT NULL CONSTRAINT UQ_CATEGORY_Name UNIQUE,
 County nvarchar(80) NULL
);
/* Single-table inheritance enforces total, disjoint specialization in one CHECK.
   Perishable products have shelf life; durable products have warranty months.
   Views expose subtypes without unenforceable cross-table minimum-cardinality rules. */
CREATE TABLE dbo.PRODUCT (
 ProductId int NOT NULL CONSTRAINT PK_PRODUCT PRIMARY KEY,
 SKU varchar(30) NOT NULL CONSTRAINT UQ_PRODUCT_SKU UNIQUE,
 ProductName nvarchar(120) NOT NULL,
 Description nvarchar(250) NULL,
 VendorId int NOT NULL CONSTRAINT FK_PRODUCT_VENDOR REFERENCES dbo.VENDOR(VendorId),
 CategoryId int NOT NULL CONSTRAINT FK_PRODUCT_CATEGORY REFERENCES dbo.PRODUCT_CATEGORY(CategoryId),
 CurrentUnitPrice decimal(12,2) NOT NULL CONSTRAINT CK_PRODUCT_Price CHECK(CurrentUnitPrice >= 0),
 ProductType char(1) NOT NULL,
 ShelfLifeDays int NULL,
 WarrantyMonths int NULL,
 CONSTRAINT CK_PRODUCT_Subtype CHECK (
  (ProductType = 'P' AND ShelfLifeDays IS NOT NULL AND ShelfLifeDays > 0 AND WarrantyMonths IS NULL)
  OR (ProductType = 'D' AND WarrantyMonths IS NOT NULL AND WarrantyMonths >= 0 AND ShelfLifeDays IS NULL))
);
CREATE TABLE dbo.CUSTOMER (
 CustomerId int NOT NULL CONSTRAINT PK_CUSTOMER PRIMARY KEY,
 FirstName nvarchar(50) NOT NULL, LastName nvarchar(50) NOT NULL,
 CustomerName AS (FirstName + N' ' + LastName),
 Phone varchar(25) NULL, StreetAddress nvarchar(150) NULL, City nvarchar(80) NULL,
 StateCode char(2) NULL, PostalCode varchar(10) NULL,
 Email nvarchar(254) NOT NULL CONSTRAINT UQ_CUSTOMER_Email UNIQUE
);
CREATE TABLE dbo.STORE_PRODUCT (
 StoreId int NOT NULL CONSTRAINT FK_STORE_PRODUCT_STORE REFERENCES dbo.STORE(StoreId),
 ProductId int NOT NULL CONSTRAINT FK_STORE_PRODUCT_PRODUCT REFERENCES dbo.PRODUCT(ProductId),
 StockQuantity int NOT NULL CONSTRAINT CK_INVENTORY_Stock CHECK(StockQuantity >= 0),
 ReorderLevel int NOT NULL CONSTRAINT CK_INVENTORY_Reorder CHECK(ReorderLevel >= 0),
 CONSTRAINT PK_STORE_PRODUCT PRIMARY KEY(StoreId, ProductId)
);
CREATE TABLE dbo.SALE (
 SaleId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_SALE PRIMARY KEY,
 StoreId int NOT NULL CONSTRAINT FK_SALE_STORE REFERENCES dbo.STORE(StoreId),
 CustomerId int NOT NULL CONSTRAINT FK_SALE_CUSTOMER REFERENCES dbo.CUSTOMER(CustomerId),
 SoldAt datetime2(0) NOT NULL,
 Description nvarchar(250) NULL
);
CREATE TABLE dbo.SALE_LINE (
 SaleId bigint NOT NULL,
 ProductId int NOT NULL,
 Quantity int NOT NULL CONSTRAINT CK_SALE_LINE_Quantity CHECK(Quantity > 0),
 UnitPriceAtSale decimal(12,2) NOT NULL CONSTRAINT CK_SALE_LINE_Price CHECK(UnitPriceAtSale >= 0),
 CONSTRAINT PK_SALE_LINE PRIMARY KEY(SaleId, ProductId),
 CONSTRAINT FK_SALE_LINE_SALE FOREIGN KEY(SaleId) REFERENCES dbo.SALE(SaleId),
 CONSTRAINT FK_SALE_LINE_PRODUCT FOREIGN KEY(ProductId) REFERENCES dbo.PRODUCT(ProductId)
);
CREATE INDEX IX_SALE_SoldAt ON dbo.SALE(SoldAt, StoreId) INCLUDE(CustomerId);
CREATE INDEX IX_SALE_LINE_Product ON dbo.SALE_LINE(ProductId) INCLUDE(Quantity, UnitPriceAtSale);
CREATE INDEX IX_STORE_Region ON dbo.STORE(RegionId);
CREATE INDEX IX_PRODUCT_Vendor ON dbo.PRODUCT(VendorId);
CREATE INDEX IX_PRODUCT_Category ON dbo.PRODUCT(CategoryId);
CREATE INDEX IX_SALE_Customer ON dbo.SALE(CustomerId);
CREATE INDEX IX_STORE_PRODUCT_Product ON dbo.STORE_PRODUCT(ProductId);
COMMIT;
GO
CREATE VIEW dbo.PERISHABLE_PRODUCT AS
 SELECT ProductId, SKU, ProductName, ShelfLifeDays FROM dbo.PRODUCT WHERE ProductType = 'P';
GO
CREATE VIEW dbo.DURABLE_PRODUCT AS
 SELECT ProductId, SKU, ProductName, WarrantyMonths FROM dbo.PRODUCT WHERE ProductType = 'D';
GO
CREATE VIEW dbo.SALE_TOTAL AS
 SELECT SaleId, SUM(CAST(Quantity AS decimal(18,0)) * UnitPriceAtSale) AS SaleTotal
 FROM dbo.SALE_LINE GROUP BY SaleId;
GO
CREATE TYPE dbo.SaleItemList AS TABLE (
 ProductId int NOT NULL PRIMARY KEY,
 Quantity int NOT NULL CHECK(Quantity > 0)
);
GO
/* The supported write API: validates all rows and atomically books/decrements stock.
   Locking serializes competing orders on the same stock, preventing overselling.
   The caller may wrap this procedure in an outer transaction; SAVEPOINT preserves it. */
CREATE PROCEDURE dbo.RecordSale
 @StoreId int, @CustomerId int, @SoldAt datetime2(0),
 @Items dbo.SaleItemList READONLY, @SaleId bigint OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM @Items) THROW 51001, 'A sale needs at least one item.', 1;
 DECLARE @InitialTranCount int = @@TRANCOUNT;
 IF @InitialTranCount = 0 BEGIN TRANSACTION;
 ELSE SAVE TRANSACTION RecordSaleSave;
 BEGIN TRY
  DECLARE @Matched int;
  SELECT @Matched = COUNT(*) FROM dbo.STORE_PRODUCT sp WITH (UPDLOCK, HOLDLOCK)
  JOIN @Items i ON i.ProductId = sp.ProductId
  WHERE sp.StoreId = @StoreId AND sp.StockQuantity >= i.Quantity;
  IF @Matched <> (SELECT COUNT(*) FROM @Items)
   THROW 51002, 'An item is not carried at this store or stock is insufficient.', 1;
  INSERT dbo.SALE(StoreId, CustomerId, SoldAt) VALUES(@StoreId,@CustomerId,@SoldAt);
  SET @SaleId = CONVERT(bigint,SCOPE_IDENTITY());
  INSERT dbo.SALE_LINE(SaleId, ProductId, Quantity, UnitPriceAtSale)
  SELECT @SaleId,i.ProductId,i.Quantity,p.CurrentUnitPrice
  FROM @Items i JOIN dbo.PRODUCT p WITH (HOLDLOCK) ON p.ProductId=i.ProductId;
  UPDATE sp SET StockQuantity=sp.StockQuantity-i.Quantity
  FROM dbo.STORE_PRODUCT sp JOIN @Items i ON i.ProductId=sp.ProductId WHERE sp.StoreId=@StoreId;
  IF @InitialTranCount = 0 COMMIT;
 END TRY
 BEGIN CATCH
  IF @InitialTranCount = 0 AND XACT_STATE() <> 0 ROLLBACK;
  ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION RecordSaleSave;
  THROW;
 END CATCH
END;
GO
/* Application role cannot bypass the supported transactional write path.
   No login is created or granted access; membership is an administrator decision. */
CREATE ROLE MarketHubSalesClerk;
GRANT EXECUTE ON dbo.RecordSale TO MarketHubSalesClerk;
GRANT EXECUTE ON TYPE::dbo.SaleItemList TO MarketHubSalesClerk;
GRANT REFERENCES ON TYPE::dbo.SaleItemList TO MarketHubSalesClerk;
GRANT SELECT ON dbo.PRODUCT TO MarketHubSalesClerk;
GRANT SELECT ON dbo.STORE_PRODUCT TO MarketHubSalesClerk;
GRANT SELECT ON dbo.SALE_TOTAL TO MarketHubSalesClerk;
DENY INSERT, UPDATE, DELETE ON dbo.SALE TO MarketHubSalesClerk;
DENY INSERT, UPDATE, DELETE ON dbo.SALE_LINE TO MarketHubSalesClerk;
DENY INSERT, UPDATE, DELETE ON dbo.STORE_PRODUCT TO MarketHubSalesClerk;
GO
