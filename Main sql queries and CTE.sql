
-- Q1: Total Sales and Profit Trend by Year
SELECT 
    d.year_num,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_units_sold
FROM fact_sales f
JOIN dim_date d ON f.order_date_key = d.date_key
GROUP BY d.year_num
ORDER BY d.year_num;

-- Q2: Sales Breakdown by Product Category & Sub-Category
SELECT 
    p.category,
    p.sub_category,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY p.category, p.sub_category
ORDER BY p.category, total_sales DESC;

-- Q3: Regional Sales and Performance Analysis
SELECT 
    l.region,
    COUNT(DISTINCT l.state) AS total_states,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    AVG(f.shipping_days) AS avg_shipping_days
FROM fact_sales f
JOIN dim_location l ON f.location_key = l.location_key
GROUP BY l.region
ORDER BY total_sales DESC;

-- Q4: Customer Segment Contribution Analysis
SELECT 
    c.segment,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.sales) * 100.0 / SUM(SUM(f.sales)) OVER() AS sales_percentage
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.segment
ORDER BY total_sales DESC;

-- Q5: CTE 1 - Monthly Sales Trends with Running Totals
WITH MonthlySales AS (
    SELECT 
        d.year_num,
        d.month_num,
        d.month_name,
        SUM(f.sales) AS monthly_sales
    FROM fact_sales f
    JOIN dim_date d ON f.order_date_key = d.date_key
    GROUP BY d.year_num, d.month_num, d.month_name
)
SELECT 
    year_num,
    month_name,
    monthly_sales,
    SUM(monthly_sales) OVER (PARTITION BY year_num ORDER BY month_num) AS ytd_sales
FROM MonthlySales
ORDER BY year_num, month_num;

-- Q6: Top 10 Most Profitable Products
SELECT TOP 10
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_profit DESC;

-- Q7: Bottom 10 Loss-Making Products
SELECT TOP 10
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_profit ASC;

-- Q8: Shipping Mode Efficiency and Cost Analysis
SELECT 
    sm.ship_mode,
    COUNT(f.sales) AS total_orders,
    AVG(CAST(f.shipping_days AS FLOAT)) AS avg_shipping_days,
    SUM(f.sales) AS total_sales
FROM fact_sales f
JOIN dim_ship_mode sm ON f.ship_mode_key = sm.ship_mode_key
GROUP BY sm.ship_mode
ORDER BY avg_shipping_days;

-- Q9: Weekend vs Weekday Sales Performance (using CASE)
SELECT 
    CASE WHEN d.is_weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(f.sales) AS total_transactions,
    SUM(f.sales) AS total_sales,
    AVG(f.sales) AS avg_order_value
FROM fact_sales f
JOIN dim_date d ON f.order_date_key = d.date_key
GROUP BY d.is_weekend;

-- Q10: Customer Value Ranking using Window Functions
SELECT TOP 20
    c.customer_name,
    c.segment,
    SUM(f.sales) AS total_spent,
    RANK() OVER (ORDER BY SUM(f.sales) DESC) AS customer_sales_rank
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.customer_name, c.segment;

-- Q11: CTE 2 - High-Value States Analysis (States with Sales > $50,000)
WITH StateSales AS (
    SELECT 
        l.state,
        l.region,
        SUM(f.sales) AS total_sales,
        SUM(f.profit) AS total_profit
    FROM fact_sales f
    JOIN dim_location l ON f.location_key = l.location_key
    GROUP BY l.state, l.region
)
SELECT 
    state,
    region,
    total_sales,
    total_profit
FROM StateSales
WHERE total_sales > 50000
ORDER BY total_sales DESC;

-- Q12: Discount Impact on Profitability (using CASE brackets)
SELECT 
    CASE 
        WHEN f.discount = 0 THEN 'No Discount'
        WHEN f.discount <= 0.2 THEN 'Low Discount (0-20%)'
        WHEN f.discount <= 0.5 THEN 'Medium Discount (21-50%)'
        ELSE 'High Discount (>50%)'
    END AS discount_bracket,
    COUNT(f.sales) AS order_count,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    AVG(f.profit) AS avg_profit_per_order
FROM fact_sales f
GROUP BY 
    CASE 
        WHEN f.discount = 0 THEN 'No Discount'
        WHEN f.discount <= 0.2 THEN 'Low Discount (0-20%)'
        WHEN f.discount <= 0.5 THEN 'Medium Discount (21-50%)'
        ELSE 'High Discount (>50%)'
    END
ORDER BY total_profit DESC;

-- Q13: State-Level Profit Margins
SELECT TOP 15
    l.state,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    CAST(SUM(f.profit) / NULLIF(SUM(f.sales), 0) * 100 AS DECIMAL(5,2)) AS profit_margin_pct
FROM fact_sales f
JOIN dim_location l ON f.location_key = l.location_key
GROUP BY l.state
HAVING SUM(f.sales) > 10000
ORDER BY profit_margin_pct DESC;

-- Q14: Repeat Customer Count and Order Frequency
SELECT 
    c.customer_name,
    COUNT(DISTINCT f.order_id) AS order_frequency,
    SUM(f.sales) AS lifetime_value
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.customer_name
HAVING COUNT(DISTINCT f.order_id) > 5
ORDER BY order_frequency DESC;

-- Q15: Quarterly KPI Summary Report
SELECT 
    d.year_num,
    d.quarter_num,
    SUM(f.sales) AS quarterly_sales,
    SUM(f.profit) AS quarterly_profit,
    SUM(f.quantity) AS quarterly_quantity_sold
FROM fact_sales f
JOIN dim_date d ON f.order_date_key = d.date_key
GROUP BY d.year_num, d.quarter_num
ORDER BY d.year_num, d.quarter_num;