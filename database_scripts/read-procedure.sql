DELIMITER //

-- Query 1: Lấy danh sách sản phẩm theo danh mục và khoảng giá (Có JOIN, WHERE, ORDER BY)
-- Mục đích: Phục vụ cho chức năng tìm kiếm, filter trên giao diện Web.
CREATE PROCEDURE sp_Get_Products_By_Filter(
    IN p_category_id BINARY(16),
    IN p_min_price DECIMAL(15,2)
)
BEGIN
    SELECT 
        p.name AS product_name,
        c.name AS category_name,
        s.store_name,
        p.base_price,
        p.status
    FROM PRODUCT p
    JOIN CATEGORY c ON p.category_id = c.category_id
    JOIN STORE s ON p.store_id = s.store_id
    WHERE p.deleted_at IS NULL 
      AND p.base_price >= p_min_price
      AND (p_category_id IS NULL OR p.category_id = p_category_id)
    ORDER BY p.base_price DESC;
END //

-- Query 2: Thống kê các cửa hàng có tổng doanh thu vượt mức chỉ định (Có JOIN, GROUP BY, HAVING, Aggregate)
-- Mục đích: Phục vụ cho màn hình Dashboard Thống kê của Super Admin.
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
    WHERE co.status = 'completed' -- Chỉ tính đơn hàng đã hoàn thành
    GROUP BY s.store_id, s.store_name
    HAVING total_revenue >= p_min_revenue
    ORDER BY total_revenue DESC;
END //

DELIMITER ;