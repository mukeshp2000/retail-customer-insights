-- Online Retail Customer Insights
-- Database: MySQL 8+
-- Revenue definition:
-- Includes rows with positive quantity and unit price.
-- Excludes cancelled invoices beginning with "C".


-- 1. Top countries by revenue from completed sales
SELECT 
    Country,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM online_retail_full
WHERE Quantity > 0
  AND UnitPrice > 0
  AND InvoiceNo NOT LIKE 'C%'
  AND Country IS NOT NULL
  AND TRIM(Country) <> ''
GROUP BY Country
ORDER BY total_revenue DESC
LIMIT 10;

-- 2. Top products by quantity sold
SELECT
    Description,
    SUM(Quantity) AS total_quantity
FROM online_retail_full
WHERE Quantity > 0
  AND UnitPrice > 0
  AND InvoiceNo NOT LIKE 'C%'
  AND Description IS NOT NULL
  AND TRIM(Description) <> ''
GROUP BY Description
ORDER BY total_quantity DESC
LIMIT 10;

-- 3. Top products by revenue
SELECT
    Description,
    ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM online_retail_full
WHERE Quantity > 0
  AND UnitPrice > 0
  AND InvoiceNo NOT LIKE 'C%'
  AND Description IS NOT NULL
  AND TRIM(Description) <> ''
GROUP BY Description
ORDER BY total_revenue DESC
LIMIT 10;

-- 4. Average order value
SELECT
    ROUND(
        SUM(Quantity * UnitPrice)
        / NULLIF(COUNT(DISTINCT InvoiceNo), 0),
        2
    ) AS average_order_value
FROM online_retail_full
WHERE Quantity > 0
  AND UnitPrice > 0
  AND InvoiceNo IS NOT NULL
  AND InvoiceNo NOT LIKE 'C%';
  
  -- 5. Monthly revenue trend
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    ROUND(SUM(Quantity * UnitPrice), 2) AS monthly_revenue
FROM online_retail_full
WHERE Quantity > 0
  AND UnitPrice > 0
  AND InvoiceNo NOT LIKE 'C%'
  AND InvoiceDate IS NOT NULL
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY sales_month;

-- 6. Top customers by revenue using RANK()
WITH customer_revenue AS (
    SELECT
        CustomerID,
        SUM(Quantity * UnitPrice) AS total_revenue
    FROM online_retail_full
    WHERE Quantity > 0
      AND UnitPrice > 0
      AND InvoiceNo NOT LIKE 'C%'
      AND CustomerID IS NOT NULL
      AND TRIM(CustomerID) <> ''
    GROUP BY CustomerID
),
ranked_customers AS (
    SELECT
        CustomerID,
        total_revenue,
        RANK() OVER (
            ORDER BY total_revenue DESC
        ) AS revenue_rank
    FROM customer_revenue
)
SELECT
    CustomerID,
    ROUND(total_revenue, 2) AS total_revenue,
    revenue_rank
FROM ranked_customers
WHERE revenue_rank <= 10
ORDER BY revenue_rank, CustomerID;

-- 7. Top customers by order count using DENSE_RANK()
WITH customer_orders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS total_orders
    FROM online_retail_full
    WHERE Quantity > 0
      AND UnitPrice > 0
      AND InvoiceNo NOT LIKE 'C%'
      AND CustomerID IS NOT NULL
      AND TRIM(CustomerID) <> ''
    GROUP BY CustomerID
),
ranked_customers AS (
    SELECT
        CustomerID,
        total_orders,
        DENSE_RANK() OVER (
            ORDER BY total_orders DESC
        ) AS order_rank
    FROM customer_orders
)
SELECT
    CustomerID,
    total_orders,
    order_rank
FROM ranked_customers
WHERE order_rank <= 10
ORDER BY order_rank, CustomerID;

-- 8. Top customer in each country using ROW_NUMBER()
WITH customer_country_revenue AS (
    SELECT
        Country,
        CustomerID,
        SUM(Quantity * UnitPrice) AS total_revenue
    FROM online_retail_full
    WHERE Quantity > 0
      AND UnitPrice > 0
      AND InvoiceNo NOT LIKE 'C%'
      AND Country IS NOT NULL
      AND TRIM(Country) <> ''
      AND CustomerID IS NOT NULL
      AND TRIM(CustomerID) <> ''
    GROUP BY Country, CustomerID
),
ranked_customers AS (
    SELECT
        Country,
        CustomerID,
        total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY total_revenue DESC, CustomerID
        ) AS customer_rank
    FROM customer_country_revenue
)
SELECT
    Country,
    CustomerID,
    ROUND(total_revenue, 2) AS total_revenue
FROM ranked_customers
WHERE customer_rank = 1
ORDER BY total_revenue DESC;

-- 9. Running total of monthly revenue using SUM() OVER()
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
        SUM(Quantity * UnitPrice) AS monthly_revenue
    FROM online_retail_full
    WHERE Quantity > 0
      AND UnitPrice > 0
      AND InvoiceNo NOT LIKE 'C%'
      AND InvoiceDate IS NOT NULL
    GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
)
SELECT
    sales_month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(
        SUM(monthly_revenue) OVER (
            ORDER BY sales_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_total_revenue
FROM monthly_revenue
ORDER BY sales_month;

-- 10. Customer contribution to total revenue
WITH valid_sales AS (
    SELECT
        CustomerID,
        Quantity * UnitPrice AS line_revenue
    FROM online_retail_full
    WHERE Quantity > 0
      AND UnitPrice > 0
      AND InvoiceNo NOT LIKE 'C%'
),
customer_revenue AS (
    SELECT
        CustomerID,
        SUM(line_revenue) AS total_revenue
    FROM valid_sales
    WHERE CustomerID IS NOT NULL
      AND TRIM(CustomerID) <> ''
    GROUP BY CustomerID
),
overall_revenue AS (
    SELECT
        SUM(line_revenue) AS total_revenue
    FROM valid_sales
)
SELECT
    cr.CustomerID,
    ROUND(cr.total_revenue, 2) AS total_revenue,
    ROUND(
        cr.total_revenue * 100.0
        / NULLIF(o.total_revenue, 0),
        2
    ) AS revenue_percentage
FROM customer_revenue AS cr
CROSS JOIN overall_revenue AS o
ORDER BY cr.total_revenue DESC
LIMIT 10;