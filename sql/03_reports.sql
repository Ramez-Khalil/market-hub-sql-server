USE MarketHubPortfolio;
GO
-- Fixed interval makes results reproducible. UTC-naive synthetic timestamps, no actual customers.
DECLARE @From datetime2(0)='2026-01-01', @Until datetime2(0)='2026-03-01';
-- 1. Revenue by region/store. All stores retained even if no sales.
SELECT r.RegionName, st.StoreName, COUNT(DISTINCT s.SaleId) AS Sales,
 COALESCE(SUM(t.SaleTotal),0) AS Revenue
FROM dbo.REGION r JOIN dbo.STORE st ON st.RegionId=r.RegionId
LEFT JOIN dbo.SALE s ON s.StoreId=st.StoreId AND s.SoldAt>=@From AND s.SoldAt<@Until
LEFT JOIN dbo.SALE_TOTAL t ON t.SaleId=s.SaleId
GROUP BY r.RegionName,st.StoreName ORDER BY Revenue DESC,st.StoreName;
-- 2. Monthly sales and basket value. Aggregation starts at sale grain, not line grain.
SELECT CONVERT(char(7),s.SoldAt,126) AS SalesMonth, COUNT(*) AS Sales,
 SUM(t.SaleTotal) AS Revenue, CAST(AVG(t.SaleTotal) AS decimal(12,2)) AS AverageBasket
FROM dbo.SALE s JOIN dbo.SALE_TOTAL t ON t.SaleId=s.SaleId
WHERE s.SoldAt>=@From AND s.SoldAt<@Until
GROUP BY CONVERT(char(7),s.SoldAt,126) ORDER BY SalesMonth;
-- 3. Product demand, including unsold products.
SELECT p.SKU,p.ProductName,COALESCE(SUM(l.Quantity),0) AS UnitsSold,
 COALESCE(SUM(CAST(l.Quantity AS decimal(18,0))*l.UnitPriceAtSale),0) AS Revenue
FROM dbo.PRODUCT p LEFT JOIN (
 SELECT sl.* FROM dbo.SALE_LINE sl JOIN dbo.SALE s ON s.SaleId=sl.SaleId
 WHERE s.SoldAt>=@From AND s.SoldAt<@Until
) l ON l.ProductId=p.ProductId
GROUP BY p.SKU,p.ProductName ORDER BY Revenue DESC,p.SKU;
-- 4. Actionable replenishment: stock at or below the reorder threshold.
SELECT s.StoreName,p.SKU,sp.StockQuantity,sp.ReorderLevel,
 sp.ReorderLevel-sp.StockQuantity+1 AS UnitsToExceedThreshold
FROM dbo.STORE_PRODUCT sp JOIN dbo.STORE s ON s.StoreId=sp.StoreId
JOIN dbo.PRODUCT p ON p.ProductId=sp.ProductId
WHERE sp.StockQuantity<=sp.ReorderLevel ORDER BY s.StoreName,p.SKU;
-- 5. Repeat customer summary with all customers retained.
SELECT c.CustomerName,COUNT(s.SaleId) AS Purchases,COALESCE(SUM(t.SaleTotal),0) AS Revenue
FROM dbo.CUSTOMER c LEFT JOIN dbo.SALE s ON s.CustomerId=c.CustomerId
 AND s.SoldAt>=@From AND s.SoldAt<@Until
LEFT JOIN dbo.SALE_TOTAL t ON t.SaleId=s.SaleId
GROUP BY c.CustomerId,c.CustomerName ORDER BY Revenue DESC,c.CustomerName;
GO
