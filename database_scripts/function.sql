USE db_assignment_2;

DELIMITER //

-- Calculate member loyalty points based on purchase history using cursor and tier thresholds
DROP FUNCTION IF EXISTS fn_Calculate_Actual_Loyalty_Points //
CREATE FUNCTION fn_Calculate_Actual_Loyalty_Points(p_buyer_id VARCHAR(36)) 
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total_points INT DEFAULT 0;
    DECLARE v_order_amount DECIMAL(15,2);
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE CONST_TIER1_THRESHOLD DECIMAL(15,2) DEFAULT 500000;
    DECLARE CONST_TIER2_THRESHOLD DECIMAL(15,2) DEFAULT 2000000;
    DECLARE CONST_POINT_UNIT DECIMAL(15,2) DEFAULT 100000;
    DECLARE CONST_BONUS_POINTS INT DEFAULT 5;
    
    -- Query to retrieve data
    DECLARE cur_orders CURSOR FOR 
        SELECT total_amount 
        FROM CUSTOMER_ORDER 
        WHERE buyer_id = p_buyer_id 
          AND status = 'completed' 
          AND is_deleted = FALSE 
          AND total_amount IS NOT NULL;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- Validate input parameters
    IF p_buyer_id IS NULL OR TRIM(p_buyer_id) = '' THEN
        RETURN 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM BUYER WHERE account_id = p_buyer_id AND is_deleted = FALSE) THEN
        RETURN 0;
    END IF;

    OPEN cur_orders;
    -- Use LOOP and cursor
    read_loop: LOOP
        FETCH cur_orders INTO v_order_amount;
        
        IF v_done THEN
            LEAVE read_loop;
        END IF;
        
        -- IF statements for calculations
        IF v_order_amount < CONST_TIER1_THRESHOLD THEN
            SET v_total_points = v_total_points + FLOOR(v_order_amount / CONST_POINT_UNIT);
        ELSEIF v_order_amount >= CONST_TIER1_THRESHOLD AND v_order_amount < CONST_TIER2_THRESHOLD THEN
            SET v_total_points = v_total_points + FLOOR((v_order_amount / CONST_POINT_UNIT) * 1.5);
        ELSE
            SET v_total_points = v_total_points + FLOOR((v_order_amount / CONST_POINT_UNIT) * 2) + CONST_BONUS_POINTS;
        END IF;
    END LOOP;
    CLOSE cur_orders;

    RETURN v_total_points;
END //

-- Calculate pure store average rating using cursors to aggregate individual review scores
DROP FUNCTION IF EXISTS fn_Calculate_Store_Average_Rating //
CREATE FUNCTION fn_Calculate_Store_Average_Rating(p_store_id VARCHAR(36)) 
RETURNS DECIMAL(3,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_sum_rating INT DEFAULT 0;
    DECLARE v_count_rating INT DEFAULT 0;
    DECLARE v_current_rating INT;
    DECLARE v_avg_rating DECIMAL(3,2) DEFAULT 0.00;
    DECLARE v_done INT DEFAULT FALSE;

    -- Query to retrieve data
    DECLARE cur_avg CURSOR FOR 
        SELECT r.rating
        FROM REVIEW r
        JOIN CUSTOMER_ORDER co ON r.order_id = co.order_id
        WHERE co.store_id = p_store_id 
          AND co.status = 'completed'
          AND co.is_deleted = FALSE
          AND r.rating IS NOT NULL 
          AND r.is_deleted = FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- Validate input parameters
    IF p_store_id IS NULL OR TRIM(p_store_id) = '' THEN
        RETURN 0.00;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM STORE WHERE store_id = p_store_id AND is_deleted = FALSE) THEN
        RETURN 0.00;
    END IF;

    OPEN cur_avg;
    -- Use LOOP and cursor
    avg_loop: LOOP
        FETCH cur_avg INTO v_current_rating;
        
        IF v_done THEN
            LEAVE avg_loop;
        END IF;
        
        SET v_sum_rating = v_sum_rating + v_current_rating;
        SET v_count_rating = v_count_rating + 1;
    END LOOP;
    CLOSE cur_avg;

    -- IF statements for calculations (prevent division by zero)
    IF v_count_rating > 0 THEN
        SET v_avg_rating = v_sum_rating / v_count_rating;
    ELSE
        SET v_avg_rating = 0.00;
    END IF;

    RETURN ROUND(v_avg_rating, 2);
END //

DELIMITER ;