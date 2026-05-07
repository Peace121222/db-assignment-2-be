USE db_assignment_2;

DELIMITER //

-- Insert a new product into the system
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
    IF p_product_id IS NULL OR LENGTH(p_product_id) <> 36 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Invalid Product ID (Must be 36-char UUID)!';
    END IF;

    IF p_store_id IS NULL OR p_category_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Store ID and Category ID cannot be null!';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' OR LENGTH(p_name) > 255 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Product name cannot be empty or exceed 255 chars!';
    END IF;

    IF p_base_price IS NULL OR p_base_price < 0 OR p_base_price > 1000000000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Base price must be between 0 and 1,000,000,000 VND!';
    END IF;

    IF EXISTS (SELECT 1 FROM PRODUCT WHERE product_id = p_product_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Product ID already exists!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM STORE WHERE store_id = p_store_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Store does not exist or has been deleted!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM CATEGORY WHERE category_id = p_category_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Category does not exist or has been deleted!';
    END IF;

    INSERT INTO PRODUCT (product_id, store_id, category_id, name, description, base_price, status, is_deleted)
    VALUES (p_product_id, p_store_id, p_category_id, TRIM(p_name), p_description, p_base_price, 'active', FALSE);
END //

-- Update an existing product's details
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
    IF NOT EXISTS (SELECT 1 FROM PRODUCT WHERE product_id = p_product_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Validation Error: Product does not exist or is already deleted!';
    END IF;

    IF p_name IS NOT NULL AND (TRIM(p_name) = '' OR LENGTH(p_name) > 255) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Validation Error: Invalid Product Name!';
    END IF;

    IF p_base_price IS NOT NULL AND (p_base_price < 0 OR p_base_price > 1000000000) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Validation Error: Invalid base price (Must be 0 - 1,000,000,000)!';
    END IF;

    IF p_status_val IS NOT NULL AND p_status_val NOT IN ('active', 'hidden', 'out_of_stock') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Validation Error: Invalid Status value!';
    END IF;

    IF p_store_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM STORE WHERE store_id = p_store_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Validation Error: New Store does not exist or has been deleted!';
    END IF;

    IF p_category_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CATEGORY WHERE category_id = p_category_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Update Validation Error: New Category does not exist or has been deleted!';
    END IF;

    UPDATE PRODUCT 
    SET 
        store_id    = COALESCE(p_store_id, store_id),
        category_id = COALESCE(p_category_id, category_id),
        name        = COALESCE(TRIM(p_name), name),
        description = COALESCE(p_description, description),
        base_price  = COALESCE(p_base_price, base_price),
        status      = COALESCE(p_status_val, status)
    WHERE product_id = p_product_id
      AND is_deleted = FALSE;
END //

-- Soft-delete a product and its associated variants safely using transactions
DROP PROCEDURE IF EXISTS sp_delete_product //
CREATE PROCEDURE sp_delete_product(
    IN p_product_id VARCHAR(36)
)
BEGIN
    DECLARE v_is_in_active_order INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_product_id IS NULL OR LENGTH(p_product_id) <> 36 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data Validation Error: Invalid Product ID format!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM PRODUCT WHERE product_id = p_product_id AND is_deleted = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deletion Error: Product does not exist or is already deleted!';
    END IF;

    SELECT COUNT(*) INTO v_is_in_active_order
    FROM PRODUCT_VARIANT pv
    JOIN ORDER_ITEM oi ON pv.variant_id = oi.variant_id
    JOIN CUSTOMER_ORDER co ON oi.order_id = co.order_id
    WHERE pv.product_id = p_product_id 
      AND pv.is_deleted = FALSE
      AND co.is_deleted = FALSE
      AND co.status IN ('pending', 'paid', 'shipping');

    IF v_is_in_active_order > 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Business Rule Violation: Cannot delete product currently in active/shipping orders. Complete or cancel orders first!';
    END IF;

    START TRANSACTION;
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
    COMMIT;
END //

DELIMITER ;