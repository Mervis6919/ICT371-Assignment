-- Scenario 3: Student Hostel Room Allocation - 202410672
-- Full corrected version

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;
DROP PROCEDURE IF EXISTS allocate_room(integer, varchar);
DROP PROCEDURE IF EXISTS check_out(integer);

-- 1. Create tables
CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) UNIQUE NOT NULL,
    total_beds INT NOT NULL CHECK (total_beds > 0),
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INT REFERENCES hostel_rooms(room_id) ON DELETE CASCADE,
    student_number VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'ALLOCATED',
    allocation_date DATE DEFAULT CURRENT_DATE
);

INSERT INTO hostel_rooms (room_number, total_beds, available_spaces) VALUES
('A101', 4, 4),
('A102', 2, 1),
('B201', 3, 3);

-- 2. IF ELSIF ELSE for room status
DO $$
DECLARE v_avail INT; v_room VARCHAR(20);
BEGIN
    SELECT room_number, available_spaces INTO v_room, v_avail FROM hostel_rooms WHERE room_id = 2;
    IF v_avail = 0 THEN RAISE NOTICE 'Room % is FULL', v_room;
    ELSIF v_avail = 1 THEN RAISE NOTICE 'Room % has ONE space left', v_room;
    ELSE RAISE NOTICE 'Room % has SEVERAL spaces - % available', v_room, v_avail;
    END IF;
END $$;

-- 3. WHILE for inspections + FOR for room checks
DO $$
DECLARE i INT := 1;
BEGIN
    RAISE NOTICE '--- Inspection Days (WHILE) ---';
    WHILE i <= 3 LOOP RAISE NOTICE 'Hostel inspection day %', i; i := i + 1; END LOOP;
    RAISE NOTICE '--- Room Checks (FOR) ---';
    FOR j IN 1..3 LOOP RAISE NOTICE 'Room check %', j; END LOOP;
END $$;

-- 4. allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(p_room_id INT, p_student_number VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    IF p_student_number IS NULL OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Invalid input: student number cannot be blank';
    END IF;

    SELECT available_spaces INTO v_avail FROM hostel_rooms WHERE room_id = p_room_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Room ID % does not exist', p_room_id; END IF;

    IF v_avail > 0 THEN
        UPDATE hostel_rooms SET available_spaces = available_spaces - 1 WHERE room_id = p_room_id;
        INSERT INTO allocations (room_id, student_number) VALUES (p_room_id, p_student_number);
        RAISE NOTICE 'Allocated room % to student %', p_room_id, p_student_number;
    ELSE
        RAISE NOTICE 'FAILED: Room % is full, cannot allocate to %', p_room_id, p_student_number;
    END IF;
END $$;

-- 5. Two valid + one to full room
CALL allocate_room(1, '202410672');
CALL allocate_room(1, '202410001');
CALL allocate_room(2, '202410002'); -- succeeds, 1 left
CALL allocate_room(2, '202410003'); -- fails, now full

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. check_out procedure
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_room INT; v_stat VARCHAR;
BEGIN
    SELECT room_id, status INTO v_room, v_stat FROM allocations WHERE allocation_id = p_allocation_id;
    IF NOT FOUND THEN RAISE NOTICE 'Allocation % not found', p_allocation_id; RETURN; END IF;

    IF v_stat = 'CHECKED_OUT' THEN
        RAISE NOTICE 'Allocation % already CHECKED_OUT - second call will NOT free another space', p_allocation_id;
    ELSE
        UPDATE allocations SET status = 'CHECKED_OUT' WHERE allocation_id = p_allocation_id;
        UPDATE hostel_rooms SET available_spaces = available_spaces + 1 WHERE room_id = v_room;
        RAISE NOTICE 'Student checked out from allocation %, 1 space freed in room %', p_allocation_id, v_room;
    END IF;
END $$;

CALL check_out(1);
CALL check_out(1); -- second call test

-- 7. Explicit cursor for full or nearly full rooms
DO $$
DECLARE c_full CURSOR FOR SELECT room_id, room_number, available_spaces FROM hostel_rooms WHERE available_spaces <= 1;
    r RECORD;
BEGIN
    RAISE NOTICE '--- Full or nearly full rooms (CURSOR) ---';
    OPEN c_full;
    LOOP FETCH c_full INTO r; EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full: Room % has % spaces left', r.room_number, r.available_spaces;
    END LOOP;
    CLOSE c_full;
END $$;

-- 8. Blank student number with EXCEPTION
DO $$
BEGIN
    CALL allocate_room(1, '   ');
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'EXCEPTION handled: %', SQLERRM;
END $$;

-- 9. Final queries
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;