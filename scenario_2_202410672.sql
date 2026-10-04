-- Scenario 2: Computer Laboratory Reservations - 202410672
-- Full corrected version

DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;
DROP PROCEDURE IF EXISTS reserve_workstations(integer, varchar, integer);
DROP PROCEDURE IF EXISTS cancel_reservation(integer);

-- 1. Create tables
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    total_workstations INT NOT NULL,
    available_workstations INT NOT NULL
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100) NOT NULL,
    num_workstations INT NOT NULL,
    status VARCHAR(20) DEFAULT 'RESERVED',
    reservation_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO lab_sessions (session_name, total_workstations, available_workstations) VALUES
('Monday Practical', 30, 30),
('Wednesday Lab', 5, 5),
('Friday Workshop', 20, 20);

-- 2. IF ELSIF ELSE
DO $$
DECLARE v_avail INT; v_name VARCHAR(100);
BEGIN
    SELECT session_name, available_workstations INTO v_name, v_avail FROM lab_sessions WHERE session_id = 2;
    IF v_avail = 0 THEN RAISE NOTICE '% is FULL', v_name;
    ELSIF v_avail <= 2 THEN RAISE NOTICE '% is NEARLY FULL - % left', v_name, v_avail;
    ELSE RAISE NOTICE '% has ENOUGH workstations - % available', v_name, v_avail;
    END IF;
END $$;

-- 3. WHILE + FOR
DO $$
DECLARE i INT := 1;
BEGIN
    RAISE NOTICE '--- Prep Reminders (WHILE) ---';
    WHILE i <= 3 LOOP RAISE NOTICE 'Session preparation reminder %', i; i := i + 1; END LOOP;
    RAISE NOTICE '--- Workstation Checks (FOR) ---';
    FOR j IN 1..3 LOOP RAISE NOTICE 'Workstation check %', j; END LOOP;
END $$;

-- 4. reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(p_session_id INT, p_lecturer VARCHAR, p_num INT)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    IF p_num <= 0 THEN RAISE EXCEPTION 'Invalid quantity %: must be >0', p_num; END IF;
    SELECT available_workstations INTO v_avail FROM lab_sessions WHERE session_id = p_session_id;
    IF v_avail >= p_num THEN
        UPDATE lab_sessions SET available_workstations = available_workstations - p_num WHERE session_id = p_session_id;
        INSERT INTO reservations (session_id, lecturer_name, num_workstations) VALUES (p_session_id, p_lecturer, p_num);
        RAISE NOTICE 'Reserved % stations for %', p_num, p_lecturer;
    ELSE
        RAISE NOTICE 'FAILED: requested % but only % available in session %', p_num, v_avail, p_session_id;
    END IF;
END $$;

-- 5. Two valid + one exceeding
CALL reserve_workstations(1, 'Dr. Mwanza', 10);
CALL reserve_workstations(1, 'Mrs. Phiri', 5);
CALL reserve_workstations(2, 'Mr. Banda', 10); -- exceeds

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. cancel_reservation procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_res_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_sess INT; v_num INT; v_stat VARCHAR;
BEGIN
    SELECT session_id, num_workstations, status INTO v_sess, v_num, v_stat FROM reservations WHERE reservation_id = p_res_id;
    IF NOT FOUND THEN RAISE NOTICE 'Reservation % not found', p_res_id; RETURN; END IF;
    IF v_stat = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % already cancelled - second call will NOT release again', p_res_id;
    ELSE
        UPDATE reservations SET status = 'CANCELLED' WHERE reservation_id = p_res_id;
        UPDATE lab_sessions SET available_workstations = available_workstations + v_num WHERE session_id = v_sess;
        RAISE NOTICE 'Reservation % cancelled, % workstations released', p_res_id, v_num;
    END IF;
END $$;

CALL cancel_reservation(1);
CALL cancel_reservation(1); -- second call must not release again

-- 7. Cursor for few workstations
DO $$
DECLARE c_low CURSOR FOR SELECT session_id, session_name, available_workstations FROM lab_sessions WHERE available_workstations <= 5;
    r RECORD;
BEGIN
    RAISE NOTICE '--- Sessions with few workstations (CURSOR) ---';
    OPEN c_low;
    LOOP FETCH c_low INTO r; EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low: % has % left', r.session_name, r.available_workstations;
    END LOOP;
    CLOSE c_low;
END $$;

-- 8. Zero workstations with EXCEPTION
DO $$
BEGIN
    CALL reserve_workstations(1, 'Test Lecturer', 0);
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXCEPTION handled: %', SQLERRM;
END $$;

-- 9. Final queries
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;