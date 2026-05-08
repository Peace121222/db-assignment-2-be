USE db_assignment_2;

DELIMITER //

-- =========================================================
-- 1) PRODUCT CRUD
-- =========================================================

-- Insert a new product safely
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
    IF p_product_id NOT REGEXP '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Invalid Product ID (must be UUID format)!';
    END IF;

    IF p_store_id IS NULL OR p_category_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Store ID and Category ID cannot be null!';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' OR LENGTH(p_name) > 255 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Product name cannot be empty or exceed 255 characters!';
    END IF;

    IF p_base_price IS NULL OR p_base_price < 0 OR p_base_price > 1000000000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Base price must be between 0 and 1,000,000,000 VND!';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM PRODUCT
        WHERE product_id = p_product_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Product ID already exists!';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM STORE
        WHERE store_id = p_store_id
          AND is_deleted = FALSE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Store does not exist or has been deleted!';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM CATEGORY
        WHERE category_id = p_category_id
          AND is_deleted = FALSE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Category does not exist or has been deleted!';
    END IF;

    INSERT INTO PRODUCT (
        product_id, store_id, category_id, name, description,
        base_price, status, is_deleted
    )
    VALUES (
        p_product_id, p_store_id, p_category_id, TRIM(p_name), p_description,
        p_base_price, 'active', FALSE
    );
END //

-- Update product information
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
    IF p_product_id NOT REGEXP '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Validation Error: Invalid Product ID (must be UUID format)!';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM PRODUCT
        WHERE product_id = p_product_id
          AND is_deleted = FALSE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Validation Error: Product does not exist or is already deleted!';
    END IF;

    IF p_name IS NOT NULL AND (TRIM(p_name) = '' OR LENGTH(p_name) > 255) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Validation Error: Invalid product name!';
    END IF;

    IF p_base_price IS NOT NULL AND (p_base_price < 0 OR p_base_price > 1000000000) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Validation Error: Base price must be between 0 and 1,000,000,000 VND!';
    END IF;

    IF p_status_val IS NOT NULL AND p_status_val NOT IN ('active', 'hidden', 'out_of_stock') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Validation Error: Invalid product status!';
    END IF;

    IF p_store_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM STORE
        WHERE store_id = p_store_id
          AND is_deleted = FALSE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Validation Error: Store does not exist or has been deleted!';
    END IF;

    IF p_category_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM CATEGORY
        WHERE category_id = p_category_id
          AND is_deleted = FALSE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Validation Error: Category does not exist or has been deleted!';
    END IF;

    UPDATE PRODUCT
    SET
        store_id    = COALESCE(p_store_id, store_id),
        category_id = COALESCE(p_category_id, category_id),
        name        = CASE WHEN p_name IS NULL THEN name ELSE TRIM(p_name) END,
        description = COALESCE(p_description, description),
        base_price  = COALESCE(p_base_price, base_price),
        status      = COALESCE(p_status_val, status)
    WHERE product_id = p_product_id
      AND is_deleted = FALSE;
END //

-- Soft-delete a product safely
DROP PROCEDURE IF EXISTS sp_Delete_Product //
CREATE PROCEDURE sp_Delete_Product(
    IN p_product_id VARCHAR(36)
)
BEGIN
    DECLARE v_is_in_active_order INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_product_id NOT REGEXP '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Invalid Product ID format!';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM PRODUCT
        WHERE product_id = p_product_id
          AND is_deleted = FALSE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Deletion Error: Product does not exist or is already deleted!';
    END IF;

    START TRANSACTION;

        SELECT COUNT(*)
        INTO v_is_in_active_order
        FROM PRODUCT_VARIANT pv
        JOIN ORDER_ITEM oi ON pv.variant_id = oi.variant_id
        JOIN CUSTOMER_ORDER co ON oi.order_id = co.order_id
        WHERE pv.product_id = p_product_id
          AND pv.is_deleted = FALSE
          AND co.is_deleted = FALSE
          AND co.status IN ('pending', 'paid', 'shipping')
        FOR UPDATE;

        IF v_is_in_active_order > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Business Rule Violation: Cannot delete product currently in active/shipping orders!';
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

    COMMIT;
END //

-- =========================================================
-- 2) ORDER STATUS / STOCK LIFECYCLE
-- =========================================================

-- Cancel an order and restore stock
-- Purpose:
-- - close the inventory gap caused by deducting stock at ORDER_ITEM insertion time
-- - ensure stock is returned exactly once when an order is cancelled
DROP PROCEDURE IF EXISTS sp_Cancel_Order //
CREATE PROCEDURE sp_Cancel_Order(
    IN p_order_id VARCHAR(36)
)
BEGIN
    DECLARE v_order_status ENUM('pending', 'paid', 'shipping', 'completed', 'cancelled');
    DECLARE v_is_deleted BOOLEAN DEFAULT FALSE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_order_id NOT REGEXP '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Invalid Order ID format!';
    END IF;

    SELECT status, is_deleted
    INTO v_order_status, v_is_deleted
    FROM CUSTOMER_ORDER
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF v_order_status IS NULL OR v_is_deleted = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cancellation Error: Order does not exist or has been deleted!';
    END IF;

    IF v_order_status = 'cancelled' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cancellation Error: Order is already cancelled!';
    END IF;

    IF v_order_status = 'completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cancellation Error: Completed orders cannot be cancelled!';
    END IF;

    START TRANSACTION;

        -- Restore stock for all items in this order
        UPDATE PRODUCT_VARIANT pv
        JOIN ORDER_ITEM oi ON pv.variant_id = oi.variant_id
        SET pv.stock = pv.stock + oi.quantity
        WHERE oi.order_id = p_order_id
          AND pv.is_deleted = FALSE;

        -- Mark the order as cancelled
        UPDATE CUSTOMER_ORDER
        SET status = 'cancelled'
        WHERE order_id = p_order_id
          AND is_deleted = FALSE;

    COMMIT;
END //

-- Optional generic status update procedure
-- This keeps status changes centralized and prevents invalid transitions
DROP PROCEDURE IF EXISTS sp_Update_Order_Status //
CREATE PROCEDURE sp_Update_Order_Status(
    IN p_order_id VARCHAR(36),
    IN p_new_status VARCHAR(20)
)
BEGIN
    DECLARE v_current_status ENUM('pending', 'paid', 'shipping', 'completed', 'cancelled');
    DECLARE v_is_deleted BOOLEAN DEFAULT FALSE;

    IF p_order_id NOT REGEXP '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Invalid Order ID format!';
    END IF;

    IF p_new_status NOT IN ('pending', 'paid', 'shipping', 'completed', 'cancelled') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: Invalid order status!';
    END IF;

    SELECT status, is_deleted
    INTO v_current_status, v_is_deleted
    FROM CUSTOMER_ORDER
    WHERE order_id = p_order_id;

    IF v_current_status IS NULL OR v_is_deleted = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Error: Order does not exist or has been deleted!';
    END IF;

    IF v_current_status = 'cancelled' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Error: Cancelled orders cannot be updated further!';
    END IF;

    IF v_current_status = 'completed' AND p_new_status <> 'completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update Error: Completed orders cannot move backward to another status!';
    END IF;

    IF p_new_status = 'cancelled' THEN
        CALL sp_Cancel_Order(p_order_id);
    ELSE
        UPDATE CUSTOMER_ORDER
        SET status = p_new_status
        WHERE order_id = p_order_id
          AND is_deleted = FALSE;
    END IF;
END //

DELIMITER ;