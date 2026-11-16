# A guided tour of MarketHubDB

## The business question

A retailer operates several stores. It needs to know which store carries a product, how much stock remains, who supplies it, and what customers bought. MarketHubDB connects these facts without copying the same customer or supplier details into every purchase.

## 1. Read the map

Start with the [conceptual model](diagrams/conceptual.svg). A store belongs to a region. Products come from vendors and belong to categories. A sale connects a customer to a store. Sale lines connect that sale to the products purchased.

**Explain it aloud:** “The sale is the receipt header. The sale lines are the individual items on the receipt.”

## 2. See the tables

Open `MarketHubDB` in SQL Server Management Studio and expand **Tables**. Inspect the customer, product, store and sales tables. A primary key identifies one row; a foreign key connects that row to a valid row elsewhere. The [data dictionary](data-dictionary.md) describes the exact columns.

**Try it:** Find a product's vendor ID, then locate that vendor. The product should not need to repeat the vendor's phone number.

## 3. Understand stock at each store

The same product can be sold by two stores while each store has a different quantity available. The store/product relationship is therefore a separate fact. Compare the stock at two stores instead of treating a product's total as stock in every location.

**Explain it aloud:** “Ten units across the company does not mean ten units at this store.”

## 4. Follow a sale

Read one sales transaction and its lines. Use joins to show the customer, store, item names, quantities and historical prices together. Historical sale prices describe what the customer paid, not what the product costs today.

**Try it:** Calculate a receipt total from its line quantities and prices. Compare the result with the reporting query.

## 5. See the rules protect the data

Run the project's test script only in the disposable practice database. Read its results before recording a pass. Tests should demonstrate that invalid references, duplicate identifiers and impossible quantities are rejected rather than silently stored.

**Explain it aloud:** “The database does not just hold information. It stops invalid relationships from entering it.”

## 6. Turn data into decisions

Use the supplied reporting queries to compare store sales and inspect inventory. Explain one result in ordinary language, then point to the rows that support it. This connects SQL syntax to a business outcome without making claims about a real company.

## Portfolio demonstration

Record a short walkthrough: show the schema, execute a join, explain one report, and show an integrity test. Use only fictional records and crop screenshots so account details and unrelated windows are not visible. Document successful execution only after observing it on SQL Server.
