USE db_assignment_2;

DELIMITER //

CREATE FUNCTION fn_Calculate_Actual_Loyalty_Points(p_buyer_id BINARY(16)) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_total_points INT DEFAULT 0;
    DECLARE v_order_amount DECIMAL(15,2);
    DECLARE v_done INT DEFAULT FALSE;
    
    DECLARE cur_orders CURSOR FOR 
        SELECT total_amount 
        FROM CUSTOMER_ORDER 
        WHERE buyer_id = p_buyer_id AND status = 'completed';
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    IF p_buyer_id IS NULL THEN
        RETURN 0;
    END IF;

    OPEN cur_orders;
    
    read_loop: LOOP
        FETCH cur_orders INTO v_order_amount;
        
        IF v_done THEN
            LEAVE read_loop;
        END IF;
        
        IF v_order_amount < 1000000 THEN
            SET v_total_points = v_total_points + FLOOR(v_order_amount / 100000);
        ELSE
            SET v_total_points = v_total_points + FLOOR((v_order_amount / 100000) * 1.5);
        END IF;
        
    END LOOP;
    
    CLOSE cur_orders;
    
    RETURN v_total_points;
END //

CREATE FUNCTION fn_Calculate_Store_Average_Rating(p_store_id BINARY(16)) 
RETURNS DECIMAL(3,2)
DETERMINISTIC
BEGIN
    DECLARE v_total_rating INT DEFAULT 0;
    DECLARE v_review_count INT DEFAULT 0;
    DECLARE v_current_rating TINYINT;
    DECLARE v_done INT DEFAULT FALSE;
    
    DECLARE cur_reviews CURSOR FOR 
        SELECT r.rating 
        FROM REVIEW r
        JOIN CUSTOMER_ORDER co ON r.order_id = co.order_id
        WHERE co.store_id = p_store_id AND r.rating IS NOT NULL;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    IF p_store_id IS NULL THEN
        RETURN 0.00;
    END IF;

    OPEN cur_reviews;
    
    read_loop: LOOP
        FETCH cur_reviews INTO v_current_rating;
        
        IF v_done THEN
            LEAVE read_loop;
        END IF;
        
        SET v_total_rating = v_total_rating + v_current_rating;
        SET v_review_count = v_review_count + 1;
    END LOOP;
    
    CLOSE cur_reviews;
    
    IF v_review_count = 0 THEN
        RETURN 0.00;
    ELSE
        RETURN CAST((v_total_rating / v_review_count) AS DECIMAL(3,2));
    END IF;
END //

DELIMITER ;