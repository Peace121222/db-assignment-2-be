USE db_assignment_2;

-- Drop existing triggers to avoid conflicts
DROP TRIGGER IF EXISTS trg_Check_Stock_Before_Insert_Order_Item;
DROP TRIGGER IF EXISTS trg_Check_Stock_Before_Update_Order_Item;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Insert;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Update;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Delete;

DELIMITER //

-- =========================================================================
-- TRIGGER 1: trg_Check_Stock_Before_Insert_Order_Item
-- PURPOSE: Enforce business constraint (Stock Availability) on INSERT.
-- REQUIREMENT 2.2.1: Validates stock and ensures the variant exists.
-- NOTE ON SYNCHRONIZATION: Actual stock deduction is handled within the 
-- checkout Stored Procedure to ensure transaction safety and avoid trigger locks.
-- =========================================================================
CREATE TRIGGER trg_Check_Stock_Before_Insert_Order_Item
BEFORE INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_variant_exists INT DEFAULT 0;

    -- Verify if the variant exists and fetch its stock
    SELECT COUNT(*), MAX(stock) INTO v_variant_exists, v_current_stock
    FROM PRODUCT_VARIANT
    WHERE variant_id = NEW.variant_id; 

    -- Validation 1: Missing Variant
    IF v_variant_exists = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Business Rule Violation: The specified product variant does not exist!';
    END IF;

    -- Validation 2: Insufficient Stock
    IF NEW.quantity > v_current_stock THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Business Rule Violation: Ordered quantity exceeds available stock!';
    END IF;
END //

-- =========================================================================
-- TRIGGER 2: trg_Check_Stock_Before_Update_Order_Item
-- PURPOSE: Enforce business constraint (Stock Availability) on UPDATE.
-- Addresses the risk of users modifying quantities or swapping variants.
-- =========================================================================
CREATE TRIGGER trg_Check_Stock_Before_Update_Order_Item
BEFORE UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_variant_exists INT DEFAULT 0;

    -- Only validate if the quantity is increased or the variant is changed
    IF NEW.quantity > OLD.quantity OR NEW.variant_id <> OLD.variant_id THEN
        SELECT COUNT(*), MAX(stock) INTO v_variant_exists, v_current_stock
        FROM PRODUCT_VARIANT
        WHERE variant_id = NEW.variant_id; 

        IF v_variant_exists = 0 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Business Rule Violation: The specified product variant does not exist!';
        END IF;

        IF NEW.quantity > v_current_stock THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Business Rule Violation: Updated quantity exceeds available stock!';
        END IF;
    END IF;
END //

-- =========================================================================
-- TRIGGERS 3, 4, 5: Derived Attribute Recalculation (total_amount)
-- REQUIREMENT 2.2.2: Compute derived attribute accurately.
-- DEPENDENCY NOTE: 'price_at_buy' must be explicitly captured from the 
-- PRODUCT table prior to calculating the order's 'total_amount'.
-- METHODOLOGY: Uses SUM() aggregation instead of incremental updates (+ / -)
-- to completely eliminate rounding errors and safeguard against negative totals.
-- =========================================================================

CREATE TRIGGER trg_Update_Total_Amount_After_Insert
AFTER INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    -- Recalculate total for the affected order
    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE((
        SELECT SUM(quantity * price_at_buy) 
        FROM ORDER_ITEM 
        WHERE order_id = NEW.order_id
    ), 0)
    WHERE order_id = NEW.order_id;
END //

CREATE TRIGGER trg_Update_Total_Amount_After_Update
AFTER UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    -- 1. Recalculate total for the new/current order
    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE((
        SELECT SUM(quantity * price_at_buy) 
        FROM ORDER_ITEM 
        WHERE order_id = NEW.order_id
    ), 0)
    WHERE order_id = NEW.order_id;

    -- 2. Handle Order Transfer: Recalculate total for the old order if the item was moved
    IF NEW.order_id <> OLD.order_id THEN
        UPDATE CUSTOMER_ORDER
        SET total_amount = COALESCE((
            SELECT SUM(quantity * price_at_buy) 
            FROM ORDER_ITEM 
            WHERE order_id = OLD.order_id
        ), 0)
        WHERE order_id = OLD.order_id;
    END IF;
END //

CREATE TRIGGER trg_Update_Total_Amount_After_Delete
AFTER DELETE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    -- Recalculate total for the affected order
    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE((
        SELECT SUM(quantity * price_at_buy) 
        FROM ORDER_ITEM 
        WHERE order_id = OLD.order_id
    ), 0)
    WHERE order_id = OLD.order_id;
END //

DELIMITER ;