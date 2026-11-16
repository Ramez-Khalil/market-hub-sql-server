/* Never drops, truncates, or replaces an existing database. Run once as an administrator. */
USE master;
GO
IF DB_ID(N'MarketHubPortfolio') IS NOT NULL
    THROW 51000, 'MarketHubPortfolio already exists. Inspect it; do not overwrite it.', 1;
GO
CREATE DATABASE MarketHubPortfolio;
GO
