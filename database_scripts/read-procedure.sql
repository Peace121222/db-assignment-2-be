USE db_assignment_2;

DELIMITER //

-- Retrieve a list of products utilizing Dynamic SQL for optimal index usage
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

    -- Khởi tạo Base Query
    SET @sql_query = 'SELECT p.product_id, p.name AS product_name, p.description, p.category_id, c.name AS category_name, p.store_id, s.store_name, p.base_price, p.status ';
    SET @sql_query = CONCAT(@sql_query, 'FROM PRODUCT p ');
    SET @sql_query = CONCAT(@sql_query, 'JOIN CATEGORY c ON p.category_id = c.category_id ');
    SET @sql_query = CONCAT(@sql_query, 'JOIN STORE s ON p.store_id = s.store_id ');
    SET @sql_query = CONCAT(@sql_query, 'WHERE p.is_deleted = FALSE AND c.is_deleted = FALSE AND s.is_deleted = FALSE ');

    -- Gắn các điều kiện động (Dynamic WHERE clauses)
    IF p_keyword IS NOT NULL THEN
        SET @p_keyword = CONCAT('%', p_keyword, '%');
        SET @sql_query = CONCAT(@sql_query, 'AND p.name LIKE @p_keyword ');
    END IF;

    IF p_category_id_val IS NOT NULL THEN
        SET @p_category_id_val = p_category_id_val;
        SET @sql_query = CONCAT(@sql_query, 'AND p.category_id = @p_category_id_val ');
    END IF;

    IF p_store_id_val IS NOT NULL THEN
        SET @p_store_id_val = p_store_id_val;
        SET @sql_query = CONCAT(@sql_query, 'AND p.store_id = @p_store_id_val ');
    END IF;

    IF p_min_price IS NOT NULL THEN
        SET @p_min_price = p_min_price;
        SET @sql_query = CONCAT(@sql_query, 'AND p.base_price >= @p_min_price ');
    END IF;

    IF p_max_price IS NOT NULL THEN
        SET @p_max_price = p_max_price;
        SET @sql_query = CONCAT(@sql_query, 'AND p.base_price <= @p_max_price ');
    END IF;

    IF p_status_val IS NOT NULL THEN
        SET @p_status_val = p_status_val;
        SET @sql_query = CONCAT(@sql_query, 'AND p.status = @p_status_val ');
    END IF;

    -- Dynamic ORDER BY (Bỏ qua ORDER BY CASE để giữ Index)
    SET @sort_col = CASE p_sort_by 
        WHEN 'price' THEN 'p.base_price' 
        WHEN 'name' THEN 'p.name' 
        ELSE 'p.created_at' 
    END;

    SET @sort_direction = IF(UPPER(p_sort_dir) = 'ASC', 'ASC', 'DESC');
    SET @sql_query = CONCAT(@sql_query, ' ORDER BY ', @sort_col, ' ', @sort_direction);

    -- Biên dịch và thực thi Query động
    PREPARE stmt FROM @sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //

-- Generates a detailed sales performance report using Window Functions (MySQL 8+)
DROP PROCEDURE IF EXISTS sp_Get_Product_Sales_Performance //
CREATE PROCEDURE sp_Get_Product_Sales_Performance(
    IN p_store_id VARCHAR(36),
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_min_quantity INT
)
BEGIN
    IF p_store_id IS NULL THEN 
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Store ID cannot be null!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM STORE WHERE store_id = p_store_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: The specified Store ID does not exist or has been deleted!';
    END IF;

    IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Start date cannot be after end date!';
    END IF;

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
          AND p.is_deleted = FALSE
          AND c.is_deleted = FALSE
          AND pv.is_deleted = FALSE
          AND co.is_deleted = FALSE
          AND co.status = 'completed' 
          AND (p_start_date IS NULL OR co.created_at >= p_start_date)
          AND (p_end_date IS NULL OR co.created_at < DATE_ADD(p_end_date, INTERVAL 1 DAY))
        GROUP BY p.product_id, p.name, c.name
        HAVING SUM(oi.quantity) >= COALESCE(p_min_quantity, 0)
    )
    SELECT 
        product_name,
        category_name,
        total_quantity_sold,
        product_revenue,
        ROUND((product_revenue / NULLIF(SUM(product_revenue) OVER (), 0)) * 100, 2) AS revenue_percentage,
        DENSE_RANK() OVER (ORDER BY product_revenue DESC) AS sales_rank
    FROM ProductStats
    ORDER BY sales_rank ASC;
END //

DELIMITER ;