USE db_assignment_2;

DELIMITER //

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
    SELECT 
        p.product_id,
        p.name AS product_name,
        c.name AS category_name,
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
      CASE WHEN p_sort_by = 'price' AND p_sort_dir = 'ASC' THEN p.base_price END ASC,
      CASE WHEN p_sort_by = 'price' AND p_sort_dir = 'DESC' THEN p.base_price END DESC,
      CASE WHEN p_sort_by = 'name' AND p_sort_dir = 'ASC' THEN p.name END ASC,
      CASE WHEN p_sort_by = 'name' AND p_sort_dir = 'DESC' THEN p.name END DESC,
      p.created_at DESC;
END //

DROP PROCEDURE IF EXISTS sp_Get_Top_Stores_Revenue //

CREATE PROCEDURE sp_Get_Top_Stores_Revenue(
    IN p_min_revenue DECIMAL(15,2)
)
BEGIN
    SELECT 
        s.store_name,
        COUNT(co.order_id) AS total_orders,
        SUM(co.total_amount) AS total_revenue
    FROM STORE s
    JOIN CUSTOMER_ORDER co ON s.store_id = co.store_id
    WHERE co.status = 'completed'
    GROUP BY s.store_id, s.store_name
    HAVING total_revenue >= p_min_revenue
    ORDER BY total_revenue DESC;
END //

DELIMITER ;