USE db_assignment_2;

DELIMITER //

-- 1. Procedure: Insert Product
CREATE PROCEDURE sp_Insert_Product(
    IN p_product_id BINARY(16),
    IN p_store_id BINARY(16),
    IN p_category_id BINARY(16),
    IN p_name VARCHAR(255),
    IN p_description TEXT,
    IN p_base_price DECIMAL(15,2)
)
BEGIN
    -- Validation: Giá sản phẩm không được âm
    IF p_base_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi dữ liệu: Giá sản phẩm (base_price) không được nhỏ hơn 0!';
    END IF;

    -- Validation: Tên sản phẩm không được để trống
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi dữ liệu: Tên sản phẩm không được để trống!';
    END IF;

    INSERT INTO PRODUCT (product_id, store_id, category_id, name, description, base_price, status)
    VALUES (p_product_id, p_store_id, p_category_id, p_name, p_description, p_base_price, 'active');
END //

-- 2. Procedure: Update Product
CREATE PROCEDURE sp_Update_Product(
    IN p_product_id BINARY(16),
    IN p_new_price DECIMAL(15,2),
    IN p_new_status ENUM('active', 'out_of_stock', 'hidden')
)
BEGIN
    -- Validation: Giá mới không được âm
    IF p_new_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi cập nhật: Giá sản phẩm mới không hợp lệ!';
    END IF;

    UPDATE PRODUCT 
    SET base_price = p_new_price, 
        status = p_new_status, 
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = p_product_id;
END //

-- 3. Procedure: Delete Product (Soft Delete)
CREATE PROCEDURE sp_delete_product(
    IN p_product_id BINARY(16)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM PRODUCT WHERE product_id = p_product_id AND deleted_at IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sản phẩm không tồn tại hoặc đã bị xóa trước đó!';
    END IF;

    UPDATE PRODUCT
    SET deleted_at = CURRENT_TIMESTAMP,
        status = 'hidden'
    WHERE product_id = p_product_id;
    
    UPDATE PRODUCT_VARIANT
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE product_id = p_product_id;
END //

DELIMITER ;