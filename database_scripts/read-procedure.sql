USE db_assignment_2;

DELIMITER //

-- =========================================================================
-- PROCEDURE 4: sp_Get_Products_By_Filter
-- PURPOSE: Retrieve a list of products with dynamic filtering and sorting.
-- REQUIREMENT 2.3: Uses WHERE, ORDER BY, and joins multiple tables.
-- PERFORMANCE NOTE: The use of "(p_param IS NULL OR column = p_param)" provides 
-- high query flexibility (Catch-all query) but may cause index scans instead of 
-- index seeks. In high-volume enterprise systems, Dynamic SQL is preferred, 
-- but this approach satisfies academic requirements gracefully.
-- =========================================================================
DROP PROCEDURE IF EXISTS sp_Get_Products_By_Filter //

CREATE PROCEDURE sp_Get_Products_By_Filter(
    IN p_keyword VARCHAR(255),
    IN p_category_id_val VARCHAR(36),
    IN p_store_id_val VARCHAR(36),
    IN p_min_price DECIMAL(15,2),
    IN p_max_price DECIMAL(15,2),
    IN p_status_val VARCHAR(20),
    IN p_sort_by VARCHAR(50),
    IN p_sort_dir VARCHAR(10)
)
BEGIN
    IF p_min_price IS NOT NULL AND p_max_price IS NOT NULL AND p_min_price > p_max_price THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Minimum price cannot be greater than maximum price!';
    END IF;

    IF p_sort_by IS NOT NULL AND p_sort_by NOT IN ('price', 'name', 'created_at') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Invalid sort_by parameter. Allowed values: price, name, created_at.';
    END IF;

    IF p_sort_dir IS NOT NULL AND UPPER(p_sort_dir) NOT IN ('ASC', 'DESC') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Invalid sort_dir parameter. Allowed values: ASC, DESC.';
    END IF;

    IF p_status_val IS NOT NULL AND p_status_val NOT IN ('active', 'hidden', 'out_of_stock') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Invalid status value!';
    END IF;

    SELECT 
        p.product_id,
        p.name AS product_name,
        p.description,
        p.category_id,
        c.name AS category_name,
        p.store_id,
        s.store_name,
        p.base_price,
        p.status
    FROM PRODUCT p
    JOIN CATEGORY c ON p.category_id = c.category_id
    JOIN STORE s ON p.store_id = s.store_id
    WHERE p.is_deleted = FALSE 
      AND (p_keyword IS NULL OR p.name LIKE CONCAT('%', p_keyword, '%'))
      AND (p_category_id_val IS NULL OR p.category_id = p_category_id_val)
      AND (p_store_id_val IS NULL OR p.store_id = p_store_id_val)
      AND (p_min_price IS NULL OR p.base_price >= p_min_price)
      AND (p_max_price IS NULL OR p.base_price <= p_max_price)
      AND (p_status_val IS NULL OR p.status = p_status_val)
    ORDER BY
    -- Sắp xếp theo Giá bán (Ép kiểu số)
    CASE WHEN p_sort_by = 'price' AND UPPER(p_sort_dir) = 'ASC' THEN p.base_price END ASC,
    CASE WHEN p_sort_by = 'price' AND UPPER(p_sort_dir) = 'DESC' THEN p.base_price END DESC,
    
    -- Sắp xếp theo Tên
    CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_dir) = 'ASC' THEN p.name END ASC,
    CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_dir) = 'DESC' THEN p.name END DESC,
    
    -- Sắp xếp theo Ngày tạo (Đảm bảo có cả ASC và DESC)
    CASE WHEN p_sort_by = 'created_at' AND UPPER(p_sort_dir) = 'ASC' THEN p.created_at END ASC,
    CASE WHEN p_sort_by = 'created_at' AND UPPER(p_sort_dir) = 'DESC' THEN p.created_at END DESC,
    
    -- Mặc định nếu không truyền hoặc lỗi tham số
    p.created_at DESC;
END //

-- =========================================================================
-- PROCEDURE 5: sp_Get_Product_Sales_Performance
-- PURPOSE: Generates a detailed sales performance report for products within a store.
-- REQUIREMENT 2.3: Uses Aggregations (SUM), GROUP BY, HAVING, WHERE, JOINs.
-- COMPLEXITY HIGHLIGHTS: 
--  - CTE (Common Table Expression) to pre-aggregate sales data cleanly.
--  - Division by zero safeguards (NULLIF).
--  - Window Functions (SUM OVER, DENSE_RANK) for dynamic percentage and ranking.
-- =========================================================================
DROP PROCEDURE IF EXISTS sp_Get_Product_Sales_Performance //

CREATE PROCEDURE sp_Get_Product_Sales_Performance(
    IN p_store_id VARCHAR(36),
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_min_quantity INT
)
BEGIN
    -- 1. Input Validation: Store Existence
    IF NOT EXISTS (SELECT 1 FROM STORE WHERE store_id = p_store_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: The specified Store ID does not exist!';
    END IF;

    -- 2. Input Validation: Date Logic
    IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Start date cannot be after end date!';
    END IF;

    -- CTE Definition: Aggregates base metrics (Quantity & Revenue) per product
    WITH ProductStats AS (
        SELECT 
            p.product_id,
            p.name AS product_name,
            c.name AS category_name,
            SUM(oi.quantity) AS total_quantity_sold,
            SUM(oi.quantity * oi.price_at_buy) AS product_revenue
        FROM PRODUCT p
        JOIN CATEGORY c ON p.category_id = c.category_id
        JOIN PRODUCT_VARIANT pv ON p.product_id = pv.product_id
        JOIN ORDER_ITEM oi ON pv.variant_id = oi.variant_id
        JOIN CUSTOMER_ORDER co ON oi.order_id = co.order_id
        WHERE p.store_id = p_store_id
          AND co.status = 'completed' 
          AND (p_start_date IS NULL OR DATE(co.created_at) >= p_start_date)
          AND (p_end_date IS NULL OR DATE(co.created_at) <= p_end_date)
        GROUP BY p.product_id, p.name, c.name
        HAVING SUM(oi.quantity) >= COALESCE(p_min_quantity, 0)
    )
    
    -- Main query utilizing Window Functions for contextual analysis
    SELECT 
        product_name,
        category_name,
        total_quantity_sold,
        product_revenue,
        -- Safeguard: NULLIF prevents "Division by Zero" if total revenue of the store is 0
        ROUND((product_revenue / NULLIF(SUM(product_revenue) OVER (), 0)) * 100, 2) AS revenue_percentage,
        -- Ranks products sequentially based on revenue (1, 2, 2, 3...)
        DENSE_RANK() OVER (ORDER BY product_revenue DESC) AS sales_rank
    FROM ProductStats
    ORDER BY sales_rank ASC;
END //

DELIMITER ;