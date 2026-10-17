-- Mini-Project 2 : Advanced SQL Data Warehouse & Business Analytics

CREATE DATABASE superstore_Main;
GO

USE superstore_Main;
GO

-- 1. Staging table 

CREATE TABLE stg_central_superstore (
    row_id          INT,
    order_id        VARCHAR(20),
    order_date      DATE,
    ship_date       DATE,
    ship_mode       VARCHAR(20),
    customer_id     VARCHAR(15),
    customer_name   VARCHAR(60),
    segment         VARCHAR(20),
    country         VARCHAR(40),
    city            VARCHAR(50),
    state           VARCHAR(40),
    postal_code     VARCHAR(10), 
    region          VARCHAR(20),
    product_id      VARCHAR(20),
    category        VARCHAR(30),
    sub_category    VARCHAR(30),
    product_name    VARCHAR(200),
    sales           DECIMAL(12,4),
    quantity        INT,
    discount        DECIMAL(4,2),
    profit          DECIMAL(12,4)
);
GO

-- ---------------------------------------------------------------------
-- 2. Dimension tables
-- ---------------------------------------------------------------------
CREATE TABLE dim_date (
    date_key        INT          PRIMARY KEY,         -- yyyymmdd
    full_date       DATE         NOT NULL,
    day_of_month    TINYINT      NOT NULL,
    day_of_week     TINYINT      NOT NULL,            -- 1 = Sunday ... 7 = Saturday
    day_name        VARCHAR(10)  NOT NULL,
    month_num       TINYINT      NOT NULL,
    month_name      VARCHAR(10)  NOT NULL,
    ym_label        CHAR(7)      NOT NULL,            -- e.g. 2014-03
    quarter_num     TINYINT      NOT NULL,
    year_num        SMALLINT     NOT NULL,
    is_weekend      TINYINT      NOT NULL,
    CONSTRAINT uq_dim_date_full UNIQUE (full_date)
);

CREATE TABLE dim_customer (
    customer_key    INT IDENTITY(1,1) PRIMARY KEY,
    customer_id     VARCHAR(15) NOT NULL,
    customer_name   VARCHAR(60) NOT NULL,
    segment         VARCHAR(20) NOT NULL,
    CONSTRAINT uq_dim_customer UNIQUE (customer_id)
);

CREATE TABLE dim_product (
    product_key     INT IDENTITY(1,1) PRIMARY KEY,
    product_id      VARCHAR(20)  NOT NULL,
    product_name    VARCHAR(200) NOT NULL,
    category        VARCHAR(30)  NOT NULL,
    sub_category    VARCHAR(30)  NOT NULL,
    CONSTRAINT uq_dim_product UNIQUE (product_id, product_name)
);

CREATE TABLE dim_location (
    location_key    INT IDENTITY(1,1) PRIMARY KEY,
    city            VARCHAR(50) NOT NULL,
    state           VARCHAR(40) NOT NULL,
    postal_code     VARCHAR(10) NOT NULL,
    region          VARCHAR(20) NOT NULL,
    country         VARCHAR(40) NOT NULL,
    CONSTRAINT uq_dim_location UNIQUE (city, state, postal_code)
);

CREATE TABLE dim_ship_mode (
    ship_mode_key   INT IDENTITY(1,1) PRIMARY KEY,
    ship_mode       VARCHAR(20) NOT NULL,
    CONSTRAINT uq_dim_ship_mode UNIQUE (ship_mode)
);

-- ---------------------------------------------------------------------
-- 3. Fact table (grain = one order line item)
-- ---------------------------------------------------------------------
CREATE TABLE fact_sales (
    sales_key       INT IDENTITY(1,1) PRIMARY KEY,
    source_row_id   INT           NOT NULL,
    order_id        VARCHAR(20)   NOT NULL,
    order_date_key  INT           NOT NULL,
    ship_date_key   INT           NOT NULL,
    customer_key    INT           NOT NULL,
    product_key     INT           NOT NULL,
    location_key    INT           NOT NULL,
    ship_mode_key   INT           NOT NULL,
    sales           DECIMAL(12,4) NOT NULL,
    quantity        INT           NOT NULL,
    discount        DECIMAL(4,2)  NOT NULL,
    profit          DECIMAL(12,4) NOT NULL,
    shipping_days   INT           NOT NULL,
    CONSTRAINT uq_fact_source_row UNIQUE (source_row_id),
    CONSTRAINT fk_fact_order_date FOREIGN KEY (order_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fact_ship_date  FOREIGN KEY (ship_date_key)  REFERENCES dim_date (date_key),
    CONSTRAINT fk_fact_customer   FOREIGN KEY (customer_key)   REFERENCES dim_customer (customer_key),
    CONSTRAINT fk_fact_product    FOREIGN KEY (product_key)    REFERENCES dim_product (product_key),
    CONSTRAINT fk_fact_location   FOREIGN KEY (location_key)   REFERENCES dim_location (location_key),
    CONSTRAINT fk_fact_ship_mode  FOREIGN KEY (ship_mode_key)  REFERENCES dim_ship_mode (ship_mode_key),
    CONSTRAINT ck_fact_qty        CHECK (quantity > 0),
    CONSTRAINT ck_fact_discount   CHECK (discount >= 0 AND discount <= 1),
    CONSTRAINT ck_fact_shipdays   CHECK (shipping_days >= 0)
);
GO

-- ---------------------------------------------------------------------
-- 4. Populating
-- ---------------------------------------------------------------------

-- 1. Populate dim_date
INSERT INTO dim_date (date_key, full_date, day_of_month, day_of_week, day_name,
                      month_num, month_name, ym_label, quarter_num, year_num, is_weekend)
SELECT DISTINCT 
       YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),
       d,
       DAY(d),
       DATEPART(dw, d),
       DATENAME(dw, d),
       MONTH(d),
       DATENAME(month, d),
       CAST(YEAR(d) AS VARCHAR(4)) + '-' + RIGHT('0' + CAST(MONTH(d) AS VARCHAR(2)), 2),
       DATEPART(quarter, d),
       YEAR(d),
       CASE WHEN DATEPART(dw, d) IN (1, 7) THEN 1 ELSE 0 END
FROM (
    SELECT order_date AS d FROM stg_central_superstore
    UNION
    SELECT ship_date  AS d FROM stg_central_superstore
) AS all_dates
WHERE d IS NOT NULL;

-- 2. Populate dim_customer
INSERT INTO dim_customer (customer_id, customer_name, segment)
SELECT DISTINCT TRIM(customer_id), TRIM(customer_name), TRIM(segment)
FROM stg_central_superstore;

-- 3. Populate dim_product
INSERT INTO dim_product (product_id, product_name, category, sub_category)
SELECT DISTINCT TRIM(product_id), TRIM(product_name), TRIM(category), TRIM(sub_category)
FROM stg_central_superstore;

-- 4. Populate dim_location
INSERT INTO dim_location (city, state, postal_code, region, country)
SELECT DISTINCT TRIM(city), TRIM(state), postal_code, TRIM(region), TRIM(country)
FROM stg_central_superstore;

-- 5. Populate dim_ship_mode
INSERT INTO dim_ship_mode (ship_mode)
SELECT DISTINCT TRIM(ship_mode)
FROM stg_central_superstore;

-- 6. Populate fact_sales 

INSERT INTO fact_sales (source_row_id, order_id, order_date_key, ship_date_key,
                        customer_key, product_key, location_key, ship_mode_key,
                        sales, quantity, discount, profit, shipping_days)
SELECT s.row_id,
       s.order_id,
       YEAR(s.order_date) * 10000 + MONTH(s.order_date) * 100 + DAY(s.order_date),
       YEAR(s.ship_date)  * 10000 + MONTH(s.ship_date)  * 100 + DAY(s.ship_date),
       c.customer_key,
       p.product_key,
       l.location_key,
       sm.ship_mode_key,
       s.sales,
       s.quantity,
       s.discount,
       s.profit,
       DATEDIFF(day, s.order_date, s.ship_date)
FROM stg_central_superstore s
JOIN dim_customer  c  ON TRIM(c.customer_id)  = TRIM(s.customer_id)
JOIN dim_product   p  ON TRIM(p.product_id)   = TRIM(s.product_id)
                     AND TRIM(p.product_name) = TRIM(s.product_name)
JOIN dim_location  l  ON TRIM(l.city)         = TRIM(s.city)
                     AND TRIM(l.state)        = TRIM(s.state)
                     AND l.postal_code  = s.postal_code
JOIN dim_ship_mode sm ON TRIM(sm.ship_mode)   = TRIM(s.ship_mode);
GO

-- ---------------------------------------------------------------------
-- 5. Data-quality / reconciliation checks
-- ---------------------------------------------------------------------
SELECT 'row count reconciles' AS check_name,
       CASE WHEN (SELECT COUNT(*) FROM stg_central_superstore) = (SELECT COUNT(*) FROM fact_sales)
            THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
SELECT 'sales total reconciles',
       CASE WHEN ROUND((SELECT SUM(sales) FROM stg_central_superstore), 2)
                 = ROUND((SELECT SUM(sales) FROM fact_sales), 2) THEN 'OK' ELSE 'FAIL' END
UNION ALL
SELECT 'profit total reconciles',
       CASE WHEN ROUND((SELECT SUM(profit) FROM stg_central_superstore), 2)
                 = ROUND((SELECT SUM(profit) FROM fact_sales), 2) THEN 'OK' ELSE 'FAIL' END
UNION ALL
SELECT 'no orphan customer keys',
       CASE WHEN (SELECT COUNT(*) FROM fact_sales f
                  LEFT JOIN dim_customer c ON c.customer_key = f.customer_key
                  WHERE c.customer_key IS NULL) = 0 THEN 'OK' ELSE 'FAIL' END
UNION ALL
SELECT 'ship date never before order date',
       CASE WHEN (SELECT COUNT(*) FROM fact_sales WHERE shipping_days < 0) = 0
            THEN 'OK' ELSE 'FAIL' END;

-- Row counts per table summary
SELECT 'dim_date' AS tbl, COUNT(*) AS n FROM dim_date
UNION ALL SELECT 'dim_customer',  COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product',   COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_location',  COUNT(*) FROM dim_location
UNION ALL SELECT 'dim_ship_mode', COUNT(*) FROM dim_ship_mode
UNION ALL SELECT 'fact_sales',    COUNT(*) FROM fact_sales;
GO




