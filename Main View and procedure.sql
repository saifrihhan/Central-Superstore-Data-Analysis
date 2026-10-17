USE superstore_Main;
GO

-- Create View for Executive Reporting & KPI Monitoring
CREATE VIEW vw_executive_sales_summary AS
SELECT 
    d.year_num,
    d.quarter_num,
    d.month_num,
    d.month_name,
    l.region,
    l.state,
    p.category,
    p.sub_category,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_quantity,
    CAST(SUM(f.profit) / NULLIF(SUM(f.sales), 0) * 100 AS DECIMAL(5,2)) AS profit_margin_pct
FROM fact_sales f
JOIN dim_date d ON f.order_date_key = d.date_key
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY d.year_num, d.quarter_num, d.month_num, d.month_name, l.region, l.state, p.category, p.sub_category;
GO



-- Create Stored Procedure for Parameterized Customer Reports
CREATE PROCEDURE sp_get_top_customers
    @TopN INT = 10,
    @Segment VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        c.customer_id,
        c.customer_name,
        c.segment,
        SUM(f.sales) AS total_sales,
        SUM(f.profit) AS total_profit,
        COUNT(DISTINCT f.order_id) AS total_orders
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    WHERE @Segment IS NULL OR c.segment = @Segment
    GROUP BY c.customer_id, c.customer_name, c.segment
    ORDER BY total_sales DESC;
END;
GO

