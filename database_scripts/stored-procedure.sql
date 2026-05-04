USE db_assignment_2;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_Insert_Product //
CREATE PROCEDURE sp_Insert_Product(
    IN p_product_id VARCHAR(36),
    IN p_store_id VARCHAR(36),
    IN p_category_id VARCHAR(36),
    IN p_name VARCHAR(255),
    IN p_description TEXT,
    IN p_base_price DECIMAL(15,2)
)
BEGIN
    IF p_base_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi dữ liệu: Giá sản phẩm không được nhỏ hơn 0!';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi dữ liệu: Tên sản phẩm không được để trống!';
    END IF;

    INSERT INTO PRODUCT (product_id, store_id, category_id, name, description, base_price, status, is_deleted)
    VALUES (p_product_id, p_store_id, p_category_id, p_name, p_description, p_base_price, 'active', FALSE);
END //

DROP PROCEDURE IF EXISTS sp_Update_Product //
CREATE PROCEDURE sp_Update_Product(
    IN p_product_id VARCHAR(36),
    IN p_store_id VARCHAR(36),
    IN p_category_id VARCHAR(36),
    IN p_name VARCHAR(255),
    IN p_description TEXT,
    IN p_base_price DECIMAL(15,2),
    IN p_status_val VARCHAR(20)
)
BEGIN
    IF p_base_price IS NOT NULL AND p_base_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi cập nhật: Giá sản phẩm mới không hợp lệ!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM PRODUCT WHERE product_id = p_product_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sản phẩm không tồn tại hoặc đã bị xóa!';
    END IF;

    UPDATE PRODUCT 
    SET 
        store_id    = COALESCE(p_store_id, store_id),
        category_id = COALESCE(p_category_id, category_id),
        name        = COALESCE(p_name, name),
        description = COALESCE(p_description, description),
        base_price  = COALESCE(p_base_price, base_price),
        status      = COALESCE(p_status_val, status)
    WHERE product_id = p_product_id;
END //

DROP PROCEDURE IF EXISTS sp_delete_product //
CREATE PROCEDURE sp_delete_product(
    IN p_product_id VARCHAR(36)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM PRODUCT WHERE product_id = p_product_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sản phẩm không tồn tại!';
    END IF;

    UPDATE PRODUCT
    SET is_deleted = TRUE,
        deleted_at = CURRENT_TIMESTAMP,
        status = 'hidden'
    WHERE product_id = p_product_id;

    UPDATE PRODUCT_VARIANT
    SET is_deleted = TRUE,
        deleted_at = CURRENT_TIMESTAMP,
        stock = 0
    WHERE product_id = p_product_id;
END //

DELIMITER ;