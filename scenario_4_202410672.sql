-- Scenario 4: Campus Clinic Medicine Dispensing - 202410672
-- Full corrected version - no errors

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;
DROP PROCEDURE IF EXISTS dispense_medicine(integer, varchar, integer);
DROP PROCEDURE IF EXISTS reverse_dispensing(integer);

-- 1. Create tables
CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) DEFAULT 'DISPENSED',
    dispense_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol', 50),
('Amoxicillin', 3),
('Ibuprofen', 20);

-- 2. IF ELSIF ELSE for stock level
DO $$
DECLARE v_stock INT; v_name VARCHAR(100);
BEGIN
    SELECT medicine_name, stock_quantity INTO v_name, v_stock FROM medicines WHERE medicine_id = 2;
    IF v_stock = 0 THEN RAISE NOTICE '% is OUT OF STOCK', v_name;
    ELSIF v_stock <= 5 THEN RAISE NOTICE '% is LOW on stock - % left', v_name, v_stock;
    ELSE RAISE NOTICE '% is SUFFICIENTLY STOCKED - % available', v_name, v_stock;
    END IF;
END $$;

-- 3. WHILE for stock review + FOR for shelf inspections
DO $$
DECLARE i INT := 1;
BEGIN
    RAISE NOTICE '--- Stock Review Days (WHILE) ---';
    WHILE i <= 3 LOOP RAISE NOTICE 'Stock review day %', i; i := i + 1; END LOOP;
    RAISE NOTICE '--- Shelf Inspections (FOR) ---';
    FOR j IN 1..3 LOOP RAISE NOTICE 'Shelf inspection %', j; END LOOP;
END $$;

-- 4. dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(p_medicine_id INT, p_student_number VARCHAR, p_quantity INT)
LANGUAGE plpgsql AS $$
DECLARE v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN RAISE EXCEPTION 'Invalid input: quantity % must be >0, negative not allowed', p_quantity; END IF;
    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = p_medicine_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Medicine ID % does not exist', p_medicine_id; END IF;

    IF v_stock >= p_quantity THEN
        UPDATE medicines SET stock_quantity = stock_quantity - p_quantity WHERE medicine_id = p_medicine_id;
        INSERT INTO dispensing_records (medicine_id, student_number, quantity) VALUES (p_medicine_id, p_student_number, p_quantity);
        RAISE NOTICE 'Dispensed % units of medicine % to student %', p_quantity, p_medicine_id, p_student_number;
    ELSE
        RAISE NOTICE 'FAILED: requested % but only % available for medicine %', p_quantity, v_stock, p_medicine_id;
    END IF;
END $$;

-- 5. Two valid + one exceeding
CALL dispense_medicine(1, '202410672', 10);
CALL dispense_medicine(3, '202410001', 5);
CALL dispense_medicine(2, '202410002', 10); -- exceeds (only 3 available)

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. reverse_dispensing procedure - restore only once
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_med_id INT; v_qty INT; v_stat VARCHAR;
BEGIN
    SELECT medicine_id, quantity, status INTO v_med_id, v_qty, v_stat FROM dispensing_records WHERE record_id = p_record_id;
    IF NOT FOUND THEN RAISE NOTICE 'Record % not found', p_record_id; RETURN; END IF;

    IF v_stat = 'REVERSED' THEN
        RAISE NOTICE 'Record % already REVERSED - stock must be restored only once, second call does nothing', p_record_id;
    ELSE
        UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;
        UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_med_id;
        RAISE NOTICE 'Record % reversed, % units restored to medicine %', p_record_id, v_qty, v_med_id;
    END IF;
END $$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1); -- second call test - must not restore again

-- 7. Explicit cursor for low-stock threshold (<10)
DO $$
DECLARE c_low CURSOR FOR SELECT medicine_id, medicine_name, stock_quantity FROM medicines WHERE stock_quantity < 10;
    r RECORD;
BEGIN
    RAISE NOTICE '--- Medicines below low-stock threshold (CURSOR) ---';
    OPEN c_low;
    LOOP FETCH c_low INTO r; EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: % has % units', r.medicine_name, r.stock_quantity;
    END LOOP;
    CLOSE c_low;
END $$;

-- 8. Negative quantity with EXCEPTION
DO $$
BEGIN
    CALL dispense_medicine(1, '202410999', -5);
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXCEPTION handled: %', SQLERRM;
END $$;

-- 9. Final queries
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;