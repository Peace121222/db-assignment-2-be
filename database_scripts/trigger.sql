USE db_assignment_2;

DROP TRIGGER IF EXISTS trg_Prevent_Category_Loop;
DROP TRIGGER IF EXISTS trg_Check_Stock_Before_Insert_Order_Item;
DROP TRIGGER IF EXISTS trg_Check_Stock_Before_Update_Order_Item;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Insert;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Update;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Delete;

DELIMITER //

-- Prevent infinite hierarchical loop on category update
CREATE TRIGGER trg_Prevent_Category_Loop
BEFORE UPDATE ON CATEGORY
FOR EACH ROW
BEGIN
    DECLARE v_current_parent CHAR(36);
    DECLARE v_depth INT DEFAULT 0;
    SET v_current_parent = NEW.parent_id;
    
    WHILE v_current_parent IS NOT NULL AND v_depth < 100 DO
        SET v_depth = v_depth + 1;

        IF v_current_parent = NEW.category_id THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Lỗi: Vòng lặp danh mục bị phát hiện!';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM CATEGORY WHERE category_id = v_current_parent
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid category hierarchy: parent does not exist!';
        END IF;
        
        SELECT parent_id INTO v_current_parent 
        FROM CATEGORY 
        WHERE category_id = v_current_parent
        LIMIT 1;
    END WHILE;

    IF v_depth >= 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Hệ thống phát hiện phân cấp danh mục quá sâu (>100 cấp)!';
    END IF;
END //

-- Enforce business constraint (Stock Availability) on INSERT
CREATE TRIGGER trg_Check_Stock_Before_Insert_Order_Item
BEFORE INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_is_deleted BOOLEAN;
    DECLARE v_product_deleted BOOLEAN;

    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantity must be greater than 0!';
    END IF;

    SELECT pv.stock, pv.is_deleted, p.is_deleted
    INTO v_current_stock, v_is_deleted, v_product_deleted
    FROM PRODUCT_VARIANT pv
    JOIN PRODUCT p ON pv.product_id = p.product_id
    WHERE pv.variant_id = NEW.variant_id;

    IF v_current_stock IS NULL OR v_is_deleted = TRUE OR v_product_deleted = TRUE THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Business Rule Violation: Product or variant is deleted or does not exist!';
    END IF;

    IF NEW.quantity > v_current_stock THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Business Rule Violation: Ordered quantity exceeds available stock!';
    END IF;
END //

-- Enforce business constraint (Stock Availability) on UPDATE
CREATE TRIGGER trg_Check_Stock_Before_Update_Order_Item
BEFORE UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_is_deleted BOOLEAN;
    DECLARE v_product_deleted BOOLEAN;

    IF NEW.quantity > OLD.quantity OR NEW.variant_id <> OLD.variant_id THEN
        IF NEW.quantity <= 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity must be greater than 0!';
        END IF;

        SELECT pv.stock, pv.is_deleted, p.is_deleted
        INTO v_current_stock, v_is_deleted, v_product_deleted
        FROM PRODUCT_VARIANT pv
        JOIN PRODUCT p ON pv.product_id = p.product_id
        WHERE pv.variant_id = NEW.variant_id;

        IF v_current_stock IS NULL OR v_is_deleted = TRUE OR v_product_deleted = TRUE THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Business Rule Violation: Product or variant is deleted or does not exist!';
        END IF;

        IF NEW.quantity > v_current_stock THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Business Rule Violation: Updated quantity exceeds available stock!';
        END IF;
    END IF;
END //

-- Recalculate order total amount on insert
CREATE TRIGGER trg_Update_Total_Amount_After_Insert
AFTER INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE((
        SELECT SUM(quantity * price_at_buy) 
        FROM ORDER_ITEM 
        WHERE order_id = NEW.order_id
    ), 0)
    WHERE order_id = NEW.order_id
      AND is_deleted = FALSE;
END //

-- Recalculate order total amount on update
CREATE TRIGGER trg_Update_Total_Amount_After_Update
AFTER UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE((
        SELECT SUM(quantity * price_at_buy) 
        FROM ORDER_ITEM 
        WHERE order_id = NEW.order_id
    ), 0)
    WHERE order_id = NEW.order_id
      AND is_deleted = FALSE;

    IF NEW.order_id <> OLD.order_id THEN
        UPDATE CUSTOMER_ORDER
        SET total_amount = COALESCE((
            SELECT SUM(quantity * price_at_buy) 
            FROM ORDER_ITEM 
            WHERE order_id = OLD.order_id
        ), 0)
        WHERE order_id = OLD.order_id
          AND is_deleted = FALSE;
    END IF;
END //

-- Recalculate order total amount on delete
CREATE TRIGGER trg_Update_Total_Amount_After_Delete
AFTER DELETE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE CUSTOMER_ORDER
    SET total_amount = COALESCE((
        SELECT SUM(quantity * price_at_buy) 
        FROM ORDER_ITEM 
        WHERE order_id = OLD.order_id
    ), 0)
    WHERE order_id = OLD.order_id
      AND is_deleted = FALSE;
END //

DELIMITER ;