--TASK 1
SELECT 
    o.order_id,
    o.order_date,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,
    s.store_name,
    CONCAT(st.first_name, ' ', st.last_name) AS staff_full_name,
    p.product_name,
    cat.category_name,
    b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    (oi.quantity * oi.list_price * (1 - oi.discount)) AS net_line_revenue
FROM sales.orders o
INNER JOIN sales.customers c 
    ON o.customer_id = c.customer_id
INNER JOIN sales.stores s 
    ON o.store_id = s.store_id
INNER JOIN sales.staffs st 
    ON o.staff_id = st.staff_id
INNER JOIN sales.order_items oi 
    ON o.order_id = oi.order_id
INNER JOIN production.products p 
    ON oi.product_id = p.product_id
INNER JOIN production.categories cat 
    ON p.category_id = cat.category_id
INNER JOIN production.brands b 
    ON p.brand_id = b.brand_id
WHERE o.order_status = 4 
ORDER BY o.order_date DESC, o.order_id DESC;

--TASK 2
SELECT 
    s.store_name,
    COUNT(DISTINCT o.order_id) AS distinct_orders_count,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id) AS avg_order_value
FROM sales.stores s
INNER JOIN sales.orders o 
    ON s.store_id = o.store_id
INNER JOIN sales.order_items oi 
    ON o.order_id = oi.order_id
WHERE o.order_status = 4 
GROUP BY s.store_id, s.store_name
ORDER BY total_net_revenue DESC;


--TASK 3

WITH CustomerSpending AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(DISTINCT o.order_id) AS completed_order_count,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spending
    FROM sales.customers c
    INNER JOIN sales.orders o 
        ON c.customer_id = o.customer_id
    INNER JOIN sales.order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4  -- Completed orders only
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT 
    customer_id,
    customer_name,
    completed_order_count,
    total_spending
FROM CustomerSpending
WHERE total_spending > (
    SELECT AVG(total_spending) 
    FROM CustomerSpending
)
ORDER BY total_spending DESC;



--TASK 4
SELECT 
    p.product_name,
    s.store_name,
    stk.quantity AS current_quantity,
    cat.category_name,
    b.brand_name
FROM production.stocks stk
INNER JOIN production.products p 
    ON stk.product_id = p.product_id
INNER JOIN sales.stores s 
    ON stk.store_id = s.store_id
INNER JOIN production.categories cat 
    ON p.category_id = cat.category_id
INNER JOIN production.brands b 
    ON p.brand_id = b.brand_id
WHERE stk.quantity < 5
ORDER BY stk.quantity ASC, p.product_name ASC, s.store_name ASC;


--TASK 5
WITH ProductSales AS (
    SELECT 
        cat.category_name,
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
        DENSE_RANK() OVER (
            PARTITION BY cat.category_id 
            ORDER BY SUM(oi.quantity * oi.list_price * (1 - oi.discount)) DESC
        ) AS category_position
    FROM production.products p
    INNER JOIN production.categories cat 
        ON p.category_id = cat.category_id
    INNER JOIN sales.order_items oi 
        ON p.product_id = oi.product_id
    INNER JOIN sales.orders o 
        ON oi.order_id = o.order_id
    WHERE o.order_status = 4  
    GROUP BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT 
    category_name,
    product_name,
    total_units_sold,
    total_net_revenue,
    category_position
FROM ProductSales
WHERE category_position <= 3
ORDER BY category_name ASC, category_position ASC;

--TASK 6

WITH MonthlySales AS (
    SELECT 
        YEAR(o.order_date) AS order_year,
        MONTH(o.order_date) AS order_month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4  -- Completed orders only
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
)
SELECT 
    order_year AS year,
    order_month AS month,
    total_net_revenue,
    LAG(total_net_revenue, 1) OVER (
        ORDER BY order_year ASC, order_month ASC
    ) AS prev_month_total_net_revenue,
    total_net_revenue - LAG(total_net_revenue, 1) OVER (
        ORDER BY order_year ASC, order_month ASC
    ) AS revenue_change
FROM MonthlySales
ORDER BY order_year ASC, order_month ASC;

-- TASK 7 
CREATE VIEW sales.vw_customer_sales_summary AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,
    COUNT(DISTINCT o.order_id) AS total_completed_orders,
    ISNULL(SUM(oi.quantity), 0) AS total_units_purchased,
    ISNULL(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS total_net_revenue,
    MAX(o.order_date) AS most_recent_completed_order_date
FROM sales.customers c
LEFT JOIN sales.orders o 
    ON c.customer_id = o.customer_id 
   AND o.order_status = 4
LEFT JOIN sales.order_items oi 
    ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;

--TASK 8

BEGIN TRANSACTION;
UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;

SELECT 
    customer_id,
    first_name,
    last_name,
    phone
FROM sales.customers
WHERE customer_id = 1;

ROLLBACK TRANSACTION;

--TASK 9

CREATE PROCEDURE sales.usp_store_sales_report
    @store_id INT,
    @start_date DATE,
    @end_date DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @start_date > @end_date
    BEGIN
        RAISERROR('Invalid Date Range: @start_date cannot be later than @end_date.', 16, 1);
        RETURN;
    END

    SELECT 
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi 
        ON o.order_id = oi.order_id
    INNER JOIN production.products p 
        ON oi.product_id = p.product_id
    WHERE o.store_id = @store_id
      AND o.order_status = 4  
      AND o.order_date >= @start_date
      AND o.order_date <= @end_date
    GROUP BY p.product_id, p.product_name
    ORDER BY total_net_revenue DESC;
END;


--TASK 10 
SELECT 
    b.brand_name,
    COUNT(DISTINCT o.order_id) AS completed_orders_count,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
FROM production.brands b
INNER JOIN production.products p 
    ON b.brand_id = p.brand_id
INNER JOIN sales.order_items oi 
    ON p.product_id = oi.product_id
INNER JOIN sales.orders o 
    ON oi.order_id = o.order_id
WHERE o.order_status = 4  
GROUP BY b.brand_id, b.brand_name
ORDER BY total_net_revenue DESC;


