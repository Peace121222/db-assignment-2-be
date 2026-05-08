USE db_assignment_2;

-- =========================================================
-- Drop existing triggers so the script can be re-run safely
-- =========================================================
DROP TRIGGER IF EXISTS trg_Prevent_Category_Loop_Insert;
DROP TRIGGER IF EXISTS trg_Prevent_Category_Loop_Update;

DROP TRIGGER IF EXISTS trg_Before_Insert_Store_Max3;
DROP TRIGGER IF EXISTS trg_Before_Update_Store_Max3;

DROP TRIGGER IF EXISTS trg_Before_Insert_Review_Eligibility;
DROP TRIGGER IF EXISTS trg_Before_Update_Review_Eligibility;

DROP TRIGGER IF EXISTS trg_Before_Insert_Return_Request_Check;
DROP TRIGGER IF EXISTS trg_Before_Update_Return_Request_Check;

DROP TRIGGER IF EXISTS trg_Before_Insert_Order_Item;
DROP TRIGGER IF EXISTS trg_Before_Update_Order_Item;
DROP TRIGGER IF EXISTS trg_After_Insert_Order_Item;
DROP TRIGGER IF EXISTS trg_After_Update_Order_Item;
DROP TRIGGER IF EXISTS trg_After_Delete_Order_Item;

DELIMITER //

-- =========================================================
-- 1) CATEGORY: Prevent recursive hierarchy loops
--    Business rule:
--    - A category cannot become a descendant of itself
-- =========================================================

CREATE TRIGGER trg_Prevent_Category_Loop_Insert
BEFORE INSERT ON CATEGORY
FOR EACH ROW
BEGIN
    DECLARE v_current_parent VARCHAR(36);

    SET v_current_parent = NEW.parent_id;
    
    WHILE v_current_parent IS NOT NULL DO
        IF v_current_parent = NEW.category_id THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Category loop detected on insert!';
        END IF;
        
        SELECT parent_id
        INTO v_current_parent
        FROM CATEGORY
        WHERE category_id = v_current_parent;
    END WHILE;
END //

CREATE TRIGGER trg_Prevent_Category_Loop_Update
BEFORE UPDATE ON CATEGORY
FOR EACH ROW
BEGIN
    DECLARE v_current_parent VARCHAR(36);

    SET v_current_parent = NEW.parent_id;
    
    WHILE v_current_parent IS NOT NULL DO
        IF v_current_parent = NEW.category_id THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Category loop detected on update!';
        END IF;
        
        SELECT parent_id
        INTO v_current_parent
        FROM CATEGORY
        WHERE category_id = v_current_parent;
    END WHILE;
END //

-- =========================================================
-- 2) STORE: Each seller can manage at most 3 active stores
-- =========================================================

CREATE TRIGGER trg_Before_Insert_Store_Max3
BEFORE INSERT ON STORE
FOR EACH ROW
BEGIN
    DECLARE v_store_count INT;

    SELECT COUNT(*)
    INTO v_store_count
    FROM STORE
    WHERE seller_id = NEW.seller_id
      AND is_deleted = FALSE;

    IF v_store_count >= 3 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: A seller can manage at most 3 stores!';
    END IF;
END //

CREATE TRIGGER trg_Before_Update_Store_Max3
BEFORE UPDATE ON STORE
FOR EACH ROW
BEGIN
    DECLARE v_store_count INT;

    IF NEW.seller_id <> OLD.seller_id THEN
        SELECT COUNT(*)
        INTO v_store_count
        FROM STORE
        WHERE seller_id = NEW.seller_id
          AND is_deleted = FALSE;

        IF v_store_count >= 3 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Business Rule Violation: A seller can manage at most 3 stores!';
        END IF;
    END IF;
END //

-- =========================================================
-- 3) REVIEW: A buyer can review only items they actually bought
--    and only when the order has been completed
-- =========================================================

CREATE TRIGGER trg_Before_Insert_Review_Eligibility
BEFORE INSERT ON REVIEW
FOR EACH ROW
BEGIN
    DECLARE v_order_buyer_id VARCHAR(36);
    DECLARE v_order_status ENUM('pending', 'paid', 'shipping', 'completed', 'cancelled');
    DECLARE v_item_exists INT DEFAULT 0;

    -- Check that the referenced order item exists
    SELECT COUNT(*)
    INTO v_item_exists
    FROM ORDER_ITEM
    WHERE order_id = NEW.order_id
      AND variant_id = NEW.variant_id;

    IF v_item_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Review must reference an existing order item!';
    END IF;

    -- Get order owner and order status
    SELECT buyer_id, status
    INTO v_order_buyer_id, v_order_status
    FROM CUSTOMER_ORDER
    WHERE order_id = NEW.order_id
      AND is_deleted = FALSE;

    IF v_order_buyer_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Order does not exist or has been deleted!';
    END IF;

    -- The reviewing buyer must be the actual buyer of the order
    IF NEW.buyer_id <> v_order_buyer_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Buyer can only review items from their own order!';
    END IF;

    -- Only completed orders can be reviewed
    IF v_order_status <> 'completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Review is allowed only for completed orders!';
    END IF;
END //

CREATE TRIGGER trg_Before_Update_Review_Eligibility
BEFORE UPDATE ON REVIEW
FOR EACH ROW
BEGIN
    DECLARE v_order_buyer_id VARCHAR(36);
    DECLARE v_order_status ENUM('pending', 'paid', 'shipping', 'completed', 'cancelled');
    DECLARE v_item_exists INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_item_exists
    FROM ORDER_ITEM
    WHERE order_id = NEW.order_id
      AND variant_id = NEW.variant_id;

    IF v_item_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Review must reference an existing order item!';
    END IF;

    SELECT buyer_id, status
    INTO v_order_buyer_id, v_order_status
    FROM CUSTOMER_ORDER
    WHERE order_id = NEW.order_id
      AND is_deleted = FALSE;

    IF v_order_buyer_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Order does not exist or has been deleted!';
    END IF;

    IF NEW.buyer_id <> v_order_buyer_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Buyer can only review items from their own order!';
    END IF;

    IF v_order_status <> 'completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Review is allowed only for completed orders!';
    END IF;
END //

-- =========================================================
-- 4) RETURN_REQUEST: Valid only for completed orders
--    Additional checks:
--    - Return quantity cannot exceed purchased quantity
--    - Requested refund cannot exceed paid amount
--    NOTE:
--    This assumes RETURN_REQUEST has column: requested_refund_amount
-- =========================================================

CREATE TRIGGER trg_Before_Insert_Return_Request_Check
BEFORE INSERT ON RETURN_REQUEST
FOR EACH ROW
BEGIN
    DECLARE v_order_status ENUM('pending', 'paid', 'shipping', 'completed', 'cancelled');
    DECLARE v_bought_qty INT;
    DECLARE v_paid_amount DECIMAL(12,2);

    SELECT co.status, oi.quantity
    INTO v_order_status, v_bought_qty
    FROM CUSTOMER_ORDER co
    JOIN ORDER_ITEM oi ON oi.order_id = co.order_id
    WHERE co.order_id = NEW.order_id
      AND oi.variant_id = NEW.variant_id
      AND co.is_deleted = FALSE;

    IF v_order_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Return request must reference an existing order item!';
    END IF;

    IF v_order_status <> 'completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Return request is allowed only for completed orders!';
    END IF;

    IF NEW.quantity > v_bought_qty THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Return quantity exceeds purchased quantity!';
    END IF;

    SELECT amount
    INTO v_paid_amount
    FROM PAYMENT
    WHERE order_id = NEW.order_id;

    IF v_paid_amount IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Cannot create return request for an unpaid order!';
    END IF;

    IF NEW.requested_refund_amount > v_paid_amount THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Requested refund amount exceeds paid amount!';
    END IF;
END //

CREATE TRIGGER trg_Before_Update_Return_Request_Check
BEFORE UPDATE ON RETURN_REQUEST
FOR EACH ROW
BEGIN
    DECLARE v_order_status ENUM('pending', 'paid', 'shipping', 'completed', 'cancelled');
    DECLARE v_bought_qty INT;
    DECLARE v_paid_amount DECIMAL(12,2);

    SELECT co.status, oi.quantity
    INTO v_order_status, v_bought_qty
    FROM CUSTOMER_ORDER co
    JOIN ORDER_ITEM oi ON oi.order_id = co.order_id
    WHERE co.order_id = NEW.order_id
      AND oi.variant_id = NEW.variant_id
      AND co.is_deleted = FALSE;

    IF v_order_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Return request must reference an existing order item!';
    END IF;

    IF v_order_status <> 'completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Return request is allowed only for completed orders!';
    END IF;

    IF NEW.quantity > v_bought_qty THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Return quantity exceeds purchased quantity!';
    END IF;

    SELECT amount
    INTO v_paid_amount
    FROM PAYMENT
    WHERE order_id = NEW.order_id;

    IF v_paid_amount IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Cannot create return request for an unpaid order!';
    END IF;

    IF NEW.requested_refund_amount > v_paid_amount THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Requested refund amount exceeds paid amount!';
    END IF;
END //

-- =========================================================
-- 5) ORDER_ITEM (BEFORE INSERT):
--    Validate order and stock before insertion
-- =========================================================

CREATE TRIGGER trg_Before_Insert_Order_Item
BEFORE INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_is_deleted BOOLEAN;
    DECLARE v_product_deleted BOOLEAN;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_current_stock = NULL;

    IF NOT EXISTS (
        SELECT 1
        FROM CUSTOMER_ORDER
        WHERE order_id = NEW.order_id
          AND is_deleted = FALSE
          AND status <> 'cancelled'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid order: Order does not exist, has been deleted, or is already cancelled!';
    END IF;

    SELECT pv.stock, pv.is_deleted, p.is_deleted
    INTO v_current_stock, v_is_deleted, v_product_deleted
    FROM PRODUCT_VARIANT pv
    JOIN PRODUCT p ON pv.product_id = p.product_id
    WHERE pv.variant_id = NEW.variant_id
    FOR UPDATE;

    IF v_current_stock IS NULL OR v_is_deleted = TRUE OR v_product_deleted = TRUE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Product or variant is deleted or does not exist!';
    END IF;

    IF NEW.quantity > v_current_stock THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business Rule Violation: Ordered quantity exceeds available stock!';
    END IF;
END //

-- =========================================================
-- 6) ORDER_ITEM (BEFORE UPDATE):
--    Validate updated order item and stock availability
-- =========================================================

CREATE TRIGGER trg_Before_Update_Order_Item
BEFORE UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_is_deleted BOOLEAN;
    DECLARE v_product_deleted BOOLEAN;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_current_stock = NULL;

    IF NOT EXISTS (
        SELECT 1
        FROM CUSTOMER_ORDER
        WHERE order_id = NEW.order_id
          AND is_deleted = FALSE
          AND status <> 'cancelled'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid order: Order does not exist, has been deleted, or is already cancelled!';
    END IF;

    IF NEW.quantity > OLD.quantity OR NEW.variant_id <> OLD.variant_id THEN
        SELECT pv.stock, pv.is_deleted, p.is_deleted
        INTO v_current_stock, v_is_deleted, v_product_deleted
        FROM PRODUCT_VARIANT pv
        JOIN PRODUCT p ON pv.product_id = p.product_id
        WHERE pv.variant_id = NEW.variant_id
        FOR UPDATE;

        IF v_current_stock IS NULL OR v_is_deleted = TRUE OR v_product_deleted = TRUE THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Business Rule Violation: Product or variant is deleted or does not exist!';
        END IF;

        IF NEW.variant_id = OLD.variant_id THEN
            IF NEW.quantity - OLD.quantity > v_current_stock THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Business Rule Violation: Updated quantity exceeds available stock!';
            END IF;
        ELSE
            IF NEW.quantity > v_current_stock THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Business Rule Violation: Updated quantity exceeds available stock for new variant!';
            END IF;
        END IF;
    END IF;
END //

-- =========================================================
-- 7) ORDER_ITEM (AFTER INSERT):
--    - Deduct stock
--    - Recalculate order total_amount
-- =========================================================

CREATE TRIGGER trg_After_Insert_Order_Item
AFTER INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE PRODUCT_VARIANT
    SET stock = stock - NEW.quantity
    WHERE variant_id = NEW.variant_id;

    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE(
            (SELECT SUM(quantity * price_at_buy)
             FROM ORDER_ITEM
             WHERE order_id = NEW.order_id), 0
        ) + COALESCE(shipping_fee, 0)
    WHERE order_id = NEW.order_id
      AND is_deleted = FALSE;
END //

-- =========================================================
-- 8) ORDER_ITEM (AFTER UPDATE):
--    - Adjust stock based on quantity/variant changes
--    - Recalculate total_amount for affected orders
-- =========================================================

CREATE TRIGGER trg_After_Update_Order_Item
AFTER UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    IF NEW.variant_id = OLD.variant_id THEN
        UPDATE PRODUCT_VARIANT
        SET stock = stock + OLD.quantity - NEW.quantity
        WHERE variant_id = NEW.variant_id;
    ELSE
        UPDATE PRODUCT_VARIANT
        SET stock = stock + OLD.quantity
        WHERE variant_id = OLD.variant_id;

        UPDATE PRODUCT_VARIANT
        SET stock = stock - NEW.quantity
        WHERE variant_id = NEW.variant_id;
    END IF;

    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE(
            (SELECT SUM(quantity * price_at_buy)
             FROM ORDER_ITEM
             WHERE order_id = NEW.order_id), 0
        ) + COALESCE(shipping_fee, 0)
    WHERE order_id = NEW.order_id
      AND is_deleted = FALSE;

    IF NEW.order_id <> OLD.order_id THEN
        UPDATE CUSTOMER_ORDER
        SET total_amount = COALESCE(
                (SELECT SUM(quantity * price_at_buy)
                 FROM ORDER_ITEM
                 WHERE order_id = OLD.order_id), 0
            ) + COALESCE(shipping_fee, 0)
        WHERE order_id = OLD.order_id
          AND is_deleted = FALSE;
    END IF;
END //

-- =========================================================
-- 9) ORDER_ITEM (AFTER DELETE):
--    - Restore stock
--    - Recalculate total_amount
-- =========================================================

CREATE TRIGGER trg_After_Delete_Order_Item
AFTER DELETE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE PRODUCT_VARIANT
    SET stock = stock + OLD.quantity
    WHERE variant_id = OLD.variant_id;

    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE(
            (SELECT SUM(quantity * price_at_buy)
             FROM ORDER_ITEM
             WHERE order_id = OLD.order_id), 0
        ) + COALESCE(shipping_fee, 0)
    WHERE order_id = OLD.order_id
      AND is_deleted = FALSE;
END //

DELIMITER ;