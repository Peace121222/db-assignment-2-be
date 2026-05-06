DELIMITER //

-- =========================================================================
-- PROCEDURE: sp_Sweep_Bad_PQR_Products
-- PURPOSE: System cronjob to scan all active products and hide them if they 
-- violate the Poor Quality Rate (PQR) threshold based on Shopee policies.
-- LEVEL: Applied at the PRODUCT level, NOT the Store level.
-- =========================================================================
DROP PROCEDURE IF EXISTS sp_Sweep_Bad_PQR_Products //

CREATE PROCEDURE sp_Sweep_Bad_PQR_Products()
BEGIN
    DECLARE v_product_id VARCHAR(36);
    DECLARE v_bad_orders INT;
    DECLARE v_unique_bad_buyers INT;
    DECLARE v_total_eligible_orders INT;
    DECLARE v_pqr_rate DECIMAL(5,2);
    DECLARE v_done INT DEFAULT FALSE;
    
    -- Configuration Constants (Shopee Policy)
    DECLARE CONST_PQR_THRESHOLD DECIMAL(3,2) DEFAULT 0.20;
    DECLARE CONST_MIN_BAD_BUYERS INT DEFAULT 3;
    DECLARE CONST_MIN_TOTAL_ORDERS INT DEFAULT 15;
    DECLARE CONST_TIME_WINDOW_DAYS INT DEFAULT 7;

    -- Cursor to iterate over all active products
    DECLARE cur_products CURSOR FOR 
        SELECT product_id 
        FROM PRODUCT 
        WHERE status = 'active' AND is_deleted = FALSE;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    OPEN cur_products;
    
    product_loop: LOOP
        FETCH cur_products INTO v_product_id;
        IF v_done THEN 
            LEAVE product_loop; 
        END IF;
        
        -- 1. Calculate Numerator (Bad Orders & Unique Bad Buyers for this Product)
        SELECT 
            COUNT(DISTINCT r.order_id), 
            COUNT(DISTINCT co.buyer_id)
        INTO 
            v_bad_orders, 
            v_unique_bad_buyers
        FROM REVIEW r
        JOIN CUSTOMER_ORDER co ON r.order_id = co.order_id
        JOIN ORDER_ITEM oi ON co.order_id = oi.order_id AND r.variant_id = oi.variant_id
        JOIN PRODUCT_VARIANT pv ON oi.variant_id = pv.variant_id
        WHERE pv.product_id = v_product_id
          AND r.rating IN (1, 2)
          AND r.is_deleted = FALSE
          AND r.created_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL CONST_TIME_WINDOW_DAYS DAY);
          
        -- 2. Calculate Denominator (Eligible Orders based on policy wording)
        SELECT COUNT(DISTINCT co.order_id)
        INTO v_total_eligible_orders
        FROM CUSTOMER_ORDER co
        JOIN ORDER_ITEM oi ON co.order_id = oi.order_id
        JOIN PRODUCT_VARIANT pv ON oi.variant_id = pv.variant_id
        LEFT JOIN REVIEW r ON co.order_id = r.order_id AND r.is_deleted = FALSE
        WHERE pv.product_id = v_product_id
          AND (
              (co.status = 'completed' AND co.updated_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL CONST_TIME_WINDOW_DAYS DAY))
              OR 
              (r.created_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL CONST_TIME_WINDOW_DAYS DAY))
          );
          
        -- 3. Apply Enforcement Logic
        IF v_unique_bad_buyers >= CONST_MIN_BAD_BUYERS AND v_total_eligible_orders >= CONST_MIN_TOTAL_ORDERS THEN
            
            SET v_pqr_rate = v_bad_orders / v_total_eligible_orders;
            
            -- Execute Penalty: Hide the product if PQR >= 20%
            IF v_pqr_rate >= CONST_PQR_THRESHOLD THEN
                UPDATE PRODUCT 
                SET status = 'hidden',
                    updated_at = CURRENT_TIMESTAMP
                WHERE product_id = v_product_id;
            END IF;
            
        END IF;
        
    END LOOP;
    
    CLOSE cur_products;
END //

DELIMITER ;