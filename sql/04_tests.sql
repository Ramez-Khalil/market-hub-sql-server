USE MarketHubPortfolio;
GO
SELECT @@VERSION AS EngineVersion;
SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO
-- Each negative test executes in its own transaction; wrong/no error fails the suite.
CREATE PROCEDURE #ExpectError @Label nvarchar(120), @Statement nvarchar(max), @Expected int
AS
BEGIN
 DECLARE @Actual int=0;
 BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sp_executesql @Statement;
  ROLLBACK;
 END TRY
 BEGIN CATCH
  SET @Actual=ERROR_NUMBER();
  IF @@TRANCOUNT>0 ROLLBACK;
 END CATCH;
 IF @Actual <> @Expected
 BEGIN
  DECLARE @Message nvarchar(2048)=CONCAT(@Label,': expected ',@Expected,', actual ',@Actual);
  THROW 52000,@Message,1;
 END;
 PRINT CONCAT('PASS: ',@Label);
END;
GO
EXEC #ExpectError N'duplicate SKU',N'UPDATE dbo.PRODUCT SET SKU=''MH-COFFEE'' WHERE ProductId=2',2627;
EXEC #ExpectError N'missing product vendor',N'UPDATE dbo.PRODUCT SET VendorId=999 WHERE ProductId=1',547;
EXEC #ExpectError N'missing product category',N'UPDATE dbo.PRODUCT SET CategoryId=999 WHERE ProductId=1',547;
EXEC #ExpectError N'missing store region',N'UPDATE dbo.STORE SET RegionId=999 WHERE StoreId=1',547;
EXEC #ExpectError N'missing sale customer',N'UPDATE dbo.SALE SET CustomerId=999 WHERE SaleId=1',547;
EXEC #ExpectError N'missing sale store',N'UPDATE dbo.SALE SET StoreId=999 WHERE SaleId=1',547;
EXEC #ExpectError N'missing line sale',N'UPDATE dbo.SALE_LINE SET SaleId=999 WHERE SaleId=1',547;
EXEC #ExpectError N'missing line product',N'UPDATE dbo.SALE_LINE SET ProductId=999 WHERE SaleId=1 AND ProductId=1',547;
EXEC #ExpectError N'negative inventory',N'UPDATE dbo.STORE_PRODUCT SET StockQuantity=-1 WHERE StoreId=1 AND ProductId=1',547;
EXEC #ExpectError N'zero line quantity',N'UPDATE dbo.SALE_LINE SET Quantity=0 WHERE SaleId=1',547;
EXEC #ExpectError N'negative historical price',N'UPDATE dbo.SALE_LINE SET UnitPriceAtSale=-1 WHERE SaleId=1',547;
EXEC #ExpectError N'negative product price',N'UPDATE dbo.PRODUCT SET CurrentUnitPrice=-1 WHERE ProductId=1',547;
EXEC #ExpectError N'unknown subtype',N'UPDATE dbo.PRODUCT SET ProductType=''X'' WHERE ProductId=1',547;
EXEC #ExpectError N'overlapping subtype attributes',N'UPDATE dbo.PRODUCT SET WarrantyMonths=12 WHERE ProductId=1',547;
EXEC #ExpectError N'missing required subtype attribute',N'UPDATE dbo.PRODUCT SET ShelfLifeDays=NULL WHERE ProductId=1',547;
EXEC #ExpectError N'empty sale',N'DECLARE @i dbo.SaleItemList,@id bigint; EXEC dbo.RecordSale 1,1,''2026-03-01'',@i,@id OUTPUT',51001;
EXEC #ExpectError N'item not carried by store',N'DECLARE @i dbo.SaleItemList,@id bigint; INSERT @i VALUES(4,1); EXEC dbo.RecordSale 2,1,''2026-03-01'',@i,@id OUTPUT',51002;
EXEC #ExpectError N'insufficient inventory',N'DECLARE @i dbo.SaleItemList,@id bigint; INSERT @i VALUES(1,9999); EXEC dbo.RecordSale 1,1,''2026-03-01'',@i,@id OUTPUT',51002;
EXEC #ExpectError N'atomic rollback on invalid customer',N'DECLARE @i dbo.SaleItemList,@id bigint; INSERT @i VALUES(1,1); EXEC dbo.RecordSale 1,999,''2026-03-01'',@i,@id OUTPUT',547;
GO
-- Independent oracle values calculated from the six documented sample baskets.
IF (SELECT COUNT(*) FROM dbo.SALE)<>6 THROW 52001,'Expected exactly six seeded sales.',1;
IF (SELECT COUNT(*) FROM dbo.SALE_LINE)<>12 THROW 52002,'Expected twelve seeded sale lines.',1;
IF (SELECT SUM(SaleTotal) FROM dbo.SALE_TOTAL)<>262.00 THROW 52003,'Revenue oracle mismatch.',1;
IF (SELECT SUM(Quantity) FROM dbo.SALE_LINE)<>27 THROW 52004,'Unit-count oracle mismatch.',1;
IF (SELECT StockQuantity FROM dbo.STORE_PRODUCT WHERE StoreId=1 AND ProductId=1)<>15 THROW 52005,'Seed stock mismatch.',1;
IF (SELECT COUNT(*) FROM dbo.PERISHABLE_PRODUCT)<>3 OR (SELECT COUNT(*) FROM dbo.DURABLE_PRODUCT)<>3
 THROW 52006,'Subtype partition mismatch.',1;
PRINT 'PASS: seed counts, $262.00 revenue, 27 units, stock and subtype oracles';
BEGIN TRANSACTION;
UPDATE dbo.PRODUCT SET CurrentUnitPrice=99.00 WHERE ProductId=1;
IF (SELECT SUM(SaleTotal) FROM dbo.SALE_TOTAL)<>262.00 THROW 52007,'Repricing changed historical revenue.',1;
ROLLBACK;
PRINT 'PASS: historical sale prices survive product repricing';
BEGIN TRANSACTION;
DECLARE @Items dbo.SaleItemList,@Id bigint;
INSERT @Items VALUES(1,2),(2,1);
EXEC dbo.RecordSale 1,1,'2026-03-01',@Items,@Id OUTPUT;
IF (SELECT SaleTotal FROM dbo.SALE_TOTAL WHERE SaleId=@Id)<>29.00 THROW 52008,'New basket total mismatch.',1;
IF (SELECT StockQuantity FROM dbo.STORE_PRODUCT WHERE StoreId=1 AND ProductId=1)<>13 THROW 52009,'Atomic stock update failed.',1;
IF (SELECT StockQuantity FROM dbo.STORE_PRODUCT WHERE StoreId=1 AND ProductId=2)<>26 THROW 52010,'Second atomic stock update failed.',1;
ROLLBACK;
PRINT 'PASS: successful multi-item sale, both stock decrements, outer transaction rollback';
IF (SELECT COUNT(*) FROM dbo.SALE)<>6 THROW 52011,'Test cleanup failed.',1;
IF (SELECT StockQuantity FROM dbo.STORE_PRODUCT WHERE StoreId=1 AND ProductId=1)<>15 THROW 52012,'Stock cleanup failed.',1;
PRINT 'PASS: tests preserve seeded rows (identity gaps are expected)';
PRINT 'ALL TESTS PASSED';
GO
DROP PROCEDURE #ExpectError;
GO
