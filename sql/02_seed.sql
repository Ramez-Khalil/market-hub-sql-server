USE MarketHubPortfolio;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
INSERT dbo.REGION(RegionId,RegionName) VALUES(1,N'West'),(2,N'East');
INSERT dbo.STORE(StoreId,RegionId,StoreName,City) VALUES(1,1,N'Harbor Market',N'Harbor City'),(2,1,N'Meadow Market',N'Meadow City'),(3,2,N'River Market',N'River City');
INSERT dbo.VENDOR(VendorId,VendorName) VALUES(1,N'Orchard Supply'),(2,N'Everyday Goods'),(3,N'Workshop Supply');
INSERT dbo.PRODUCT_CATEGORY(CategoryId,CategoryName) VALUES(1,N'Pantry'),(2,N'Home'),(3,N'Electronics');
INSERT dbo.PRODUCT(ProductId,SKU,ProductName,VendorId,CategoryId,CurrentUnitPrice,ProductType,ShelfLifeDays,WarrantyMonths) VALUES
 (1,'MH-COFFEE',N'Ground coffee',1,1,12.50,'P',180,NULL),
 (2,'MH-OATS',N'Rolled oats',1,1,4.00,'P',365,NULL),
 (3,'MH-MUG',N'Ceramic mug',2,2,9.00,'D',NULL,0),
 (4,'MH-LAMP',N'Desk lamp',3,3,25.00,'D',NULL,24),
 (5,'MH-TEA',N'Black tea',1,1,6.50,'P',540,NULL),
 (6,'MH-CABLE',N'USB cable',3,3,8.00,'D',NULL,12);
INSERT dbo.CUSTOMER(CustomerId,FirstName,LastName,Email) VALUES
 (1,N'Jordan',N'Sample',N'jordan@example.test'),(2,N'Taylor',N'Sample',N'taylor@example.test'),
 (3,N'Morgan',N'Sample',N'morgan@example.test'),(4,N'Casey',N'Sample',N'casey@example.test');
INSERT dbo.STORE_PRODUCT VALUES
 (1,1,20,5),(1,2,30,8),(1,3,12,4),(1,4,5,3),(1,5,10,3),(1,6,20,5),
 (2,1,10,5),(2,2,20,8),(2,3,6,4),(2,5,5,3),
 (3,1,12,5),(3,3,8,4),(3,4,4,3),(3,6,10,5);
DECLARE @Items dbo.SaleItemList, @Id bigint;
INSERT @Items VALUES(1,2),(2,3);
EXEC dbo.RecordSale 1,1,'2026-01-05T10:00:00',@Items,@Id OUTPUT; -- $37.00
DELETE @Items; INSERT @Items VALUES(3,2),(4,1);
EXEC dbo.RecordSale 1,2,'2026-01-07T14:00:00',@Items,@Id OUTPUT; -- $43.00
DELETE @Items; INSERT @Items VALUES(1,1),(5,2);
EXEC dbo.RecordSale 2,3,'2026-01-12T11:30:00',@Items,@Id OUTPUT; -- $25.50
DELETE @Items; INSERT @Items VALUES(4,2),(6,3);
EXEC dbo.RecordSale 3,1,'2026-02-01T09:00:00',@Items,@Id OUTPUT; -- $74.00
DELETE @Items; INSERT @Items VALUES(2,5),(3,1);
EXEC dbo.RecordSale 2,2,'2026-02-04T12:00:00',@Items,@Id OUTPUT; -- $29.00
DELETE @Items; INSERT @Items VALUES(1,3),(6,2);
EXEC dbo.RecordSale 1,4,'2026-02-10T16:00:00',@Items,@Id OUTPUT; -- $53.50
COMMIT;
GO
