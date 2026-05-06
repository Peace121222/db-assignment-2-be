USE db_assignment_2;

DELIMITER //

-- =========================================================================
-- FUNCTION 1: fn_Calculate_Actual_Loyalty_Points
-- PURPOSE: Calculate member loyalty points based on purchase history.
-- BUSINESS RULES:
--   - Orders < 500,000 VND: 100k = 1 point
--   - Orders 500,000 - 2,000,000 VND: 100k = 1.5 points
--   - Orders > 2,000,000 VND: 100k = 2 points + 5 bonus points
-- ACADEMIC NOTE: While this could be achieved with a SUM(CASE...) query, 
-- a Cursor is intentionally used to satisfy Requirement 2.4 (Cursor, LOOP, IF).
-- =========================================================================
DROP FUNCTION IF EXISTS fn_Calculate_Actual_Loyalty_Points //
CREATE FUNCTION fn_Calculate_Actual_Loyalty_Points(p_buyer_id VARCHAR(36)) 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    -- Declare variables for cursor fetching and total calculation
    DECLARE v_total_points INT DEFAULT 0;
    DECLARE v_order_amount DECIMAL(15,2);
    DECLARE v_order_date DATETIME;
    DECLARE v_done INT DEFAULT FALSE;
    
    -- Configuration Constants (avoids hard-coding)
    DECLARE CONST_TIER1_THRESHOLD DECIMAL(15,2) DEFAULT 500000;
    DECLARE CONST_TIER2_THRESHOLD DECIMAL(15,2) DEFAULT 2000000;
    DECLARE CONST_POINT_UNIT DECIMAL(15,2) DEFAULT 100000;
    DECLARE CONST_BONUS_POINTS INT DEFAULT 5;
    
    -- Declare Cursor to fetch completed orders for the buyer
    DECLARE cur_orders CURSOR FOR 
        SELECT total_amount, created_at 
        FROM CUSTOMER_ORDER 
        WHERE buyer_id = p_buyer_id AND status = 'completed';
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- Input Validation
    IF p_buyer_id IS NULL OR TRIM(p_buyer_id) = '' THEN
        RETURN 0;
    END IF;

    OPEN cur_orders;
    
    read_loop: LOOP
        FETCH cur_orders INTO v_order_amount, v_order_date;
        
        IF v_done THEN
            LEAVE read_loop;
        END IF;
        
        -- Tiered Point Calculation Logic
        IF v_order_amount < CONST_TIER1_THRESHOLD THEN
            SET v_total_points = v_total_points + FLOOR(v_order_amount / CONST_POINT_UNIT);
        ELSEIF v_order_amount BETWEEN CONST_TIER1_THRESHOLD AND CONST_TIER2_THRESHOLD THEN
            SET v_total_points = v_total_points + FLOOR((v_order_amount / CONST_POINT_UNIT) * 1.5);
        ELSE
            SET v_total_points = v_total_points + FLOOR((v_order_amount / CONST_POINT_UNIT) * 2) + CONST_BONUS_POINTS;
        END IF;
    END LOOP;
    
    CLOSE cur_orders;

    RETURN v_total_points;
END //

-- =========================================================================
-- FUNCTION 2: fn_Calculate_Store_Average_Rating
-- PURPOSE: Calculate store average rating, applying PQR penalty if applicable.
-- BUSINESS RULES (Shopee PQR - Poor Quality Rate):
--   - PQR = (1-2 star reviews in past 7 days) / (Total reviews in past 7 days)
--   - Penalty Condition: PQR >= 20% AND at least 3 unique bad reviewers.
--   - Penalty Action: Subtract PQR percentage directly from the average rating.
-- =========================================================================
DROP FUNCTION IF EXISTS fn_Calculate_Store_Average_Rating //
CREATE FUNCTION fn_Calculate_Store_Average_Rating(p_store_id VARCHAR(36)) 
RETURNS DECIMAL(3,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    -- Variables for Base Average Calculation via Cursor
    DECLARE v_sum_rating INT DEFAULT 0;
    DECLARE v_count_rating INT DEFAULT 0;
    DECLARE v_current_rating INT;
    DECLARE v_avg_rating DECIMAL(3,2) DEFAULT 0.00;
    DECLARE v_done INT DEFAULT FALSE;
    
    -- Variables for PQR Logic
    DECLARE v_weekly_total_reviews INT DEFAULT 0;
    DECLARE v_weekly_bad_reviews INT DEFAULT 0;
    DECLARE v_unique_bad_buyers INT DEFAULT 0;
    DECLARE v_pqr_rate DECIMAL(5,2) DEFAULT 0.00;
    
    -- PQR Configuration Constants
    DECLARE CONST_PQR_PENALTY_THRESHOLD DECIMAL(3,2) DEFAULT 0.20;
    DECLARE CONST_MIN_BAD_BUYERS INT DEFAULT 3;
    DECLARE CONST_TIME_WINDOW_DAYS INT DEFAULT 7;

    -- Cursor to calculate Base Average Rating
    DECLARE cur_avg CURSOR FOR 
        SELECT r.rating
        FROM REVIEW r
        JOIN CUSTOMER_ORDER co ON r.order_id = co.order_id
        WHERE co.store_id = p_store_id 
          AND r.rating IS NOT NULL 
          AND r.is_deleted = FALSE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- Input Validation
    IF p_store_id IS NULL OR TRIM(p_store_id) = '' THEN
        RETURN 0.00;
    END IF;

    -- 1. Calculate Base Average using Cursor (Fulfills assignment requirement)
    OPEN cur_avg;
    avg_loop: LOOP
        FETCH cur_avg INTO v_current_rating;
        IF v_done THEN
            LEAVE avg_loop;
        END IF;
        
        SET v_sum_rating = v_sum_rating + v_current_rating;
        SET v_count_rating = v_count_rating + 1;
    END LOOP;
    CLOSE cur_avg;

    IF v_count_rating > 0 THEN
        SET v_avg_rating = v_sum_rating / v_count_rating;
    END IF;

    -- 2. Calculate PQR metrics within the defined time window
    SELECT 
        COUNT(*),
        SUM(CASE WHEN r.rating IN (1, 2) THEN 1 ELSE 0 END),
        COUNT(DISTINCT CASE WHEN r.rating IN (1, 2) THEN co.buyer_id ELSE NULL END)
    INTO 
        v_weekly_total_reviews,
        v_weekly_bad_reviews,
        v_unique_bad_buyers
    FROM REVIEW r
    JOIN CUSTOMER_ORDER co ON r.order_id = co.order_id
    WHERE co.store_id = p_store_id 
      AND r.is_deleted = FALSE
      AND r.rating IS NOT NULL
      AND r.created_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL CONST_TIME_WINDOW_DAYS DAY);

    -- 3. Apply Penalty if Policy is violated
    IF v_weekly_total_reviews > 0 THEN
        SET v_pqr_rate = v_weekly_bad_reviews / v_weekly_total_reviews;
        
        -- If PQR rate exceeds threshold and has enough unique bad reviewers
        IF v_pqr_rate >= CONST_PQR_PENALTY_THRESHOLD AND v_unique_bad_buyers >= CONST_MIN_BAD_BUYERS THEN
            SET v_avg_rating = v_avg_rating - v_pqr_rate;
        END IF;
    END IF;

    -- 4. Final Bounds Validation
    IF v_avg_rating < 0.00 THEN
        SET v_avg_rating = 0.00;
    ELSEIF v_avg_rating > 5.00 THEN
        SET v_avg_rating = 5.00;
    END IF;

    RETURN ROUND(v_avg_rating, 2);
END //

DELIMITER ;