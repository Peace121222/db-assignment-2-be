USE db_assignment_2;

DELIMITER //

DROP FUNCTION IF EXISTS fn_Calculate_Actual_Loyalty_Points //
CREATE FUNCTION fn_Calculate_Actual_Loyalty_Points(p_buyer_id VARCHAR(36)) 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total_points INT DEFAULT 0;

    SELECT SUM(
        CASE 
            WHEN total_amount < 1000000 THEN FLOOR(total_amount / 100000)
            ELSE FLOOR((total_amount / 100000) * 1.5)
        END
    ) INTO v_total_points
    FROM CUSTOMER_ORDER 
    WHERE buyer_id = p_buyer_id AND status = 'completed';

    RETURN IFNULL(v_total_points, 0);
END //

DROP FUNCTION IF EXISTS fn_Calculate_Store_Average_Rating //
CREATE FUNCTION fn_Calculate_Store_Average_Rating(p_store_id VARCHAR(36)) 
RETURNS DECIMAL(3,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_avg_rating DECIMAL(3,2);

    SELECT AVG(r.rating) INTO v_avg_rating
    FROM REVIEW r
    JOIN CUSTOMER_ORDER co ON r.order_id = co.order_id
    WHERE co.store_id = p_store_id 
      AND r.rating IS NOT NULL 
      AND r.is_deleted = FALSE;

    RETURN IFNULL(v_avg_rating, 0.00);
END //

DELIMITER ;