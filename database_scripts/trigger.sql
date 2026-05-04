USE shopee_pro_max;

DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Insert;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Update;
DROP TRIGGER IF EXISTS trg_Update_Total_Amount_After_Delete;

DELIMITER //

CREATE TRIGGER trg_Update_Total_Amount_After_Insert
AFTER INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE CUSTOMER_ORDER
    SET total_amount = total_amount + (NEW.quantity * NEW.price_at_buy)
    WHERE order_id = NEW.order_id;
END //

CREATE TRIGGER trg_Update_Total_Amount_After_Update
AFTER UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE CUSTOMER_ORDER
    SET total_amount = total_amount - (OLD.quantity * OLD.price_at_buy) + (NEW.quantity * NEW.price_at_buy)
    WHERE order_id = NEW.order_id;
END //

CREATE TRIGGER trg_Update_Total_Amount_After_Delete
AFTER DELETE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE CUSTOMER_ORDER
    SET total_amount = total_amount - (OLD.quantity * OLD.price_at_buy)
    WHERE order_id = OLD.order_id;
END //

DELIMITER ;