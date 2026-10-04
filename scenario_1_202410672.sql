-- Scenario 1: University Library Book Loans - 202410672

DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

-- 1. Create tables
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    author VARCHAR(100) NOT NULL,
    total_copies INT NOT NULL,
    available_copies INT NOT NULL
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES books(book_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL,
    loan_status VARCHAR(20) DEFAULT 'BORROWED',
    loan_date DATE DEFAULT CURRENT_DATE,
    return_date DATE
);

INSERT INTO books (title, author, total_copies, available_copies) VALUES
('Database Systems', 'Elmasri', 5, 5),
('Operating Systems', 'Silberschatz', 2, 2),
('Data Structures', 'Cormen', 10, 10);

-- 2. IF ELSIF ELSE for stock level
DO $$
DECLARE v_copies INT; v_title VARCHAR(100);
BEGIN
    SELECT title, available_copies INTO v_title, v_copies FROM books WHERE book_id = 2;
    IF v_copies = 0 THEN RAISE NOTICE '% is UNAVAILABLE', v_title;
    ELSIF v_copies <= 2 THEN RAISE NOTICE '% is LOW on copies - % remaining', v_title, v_copies;
    ELSE RAISE NOTICE '% is SUFFICIENTLY STOCKED', v_title;
    END IF;
END $$;

-- 3. WHILE for reminders + FOR for shelf numbers
DO $$
DECLARE i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue reminder %', i; i := i + 1;
    END LOOP;
    FOR j IN 1..3 LOOP
        RAISE NOTICE 'Shelf number: %', j;
    END LOOP;
END $$;

-- 4. borrow_book procedure
CREATE OR REPLACE PROCEDURE borrow_book(p_book_id INT, p_student_number VARCHAR, p_quantity INT)
LANGUAGE plpgsql AS $$
DECLARE v_available INT;
BEGIN
    IF p_quantity <= 0 THEN RAISE EXCEPTION 'Invalid quantity %', p_quantity; END IF;
    SELECT available_copies INTO v_available FROM books WHERE book_id = p_book_id;
    IF v_available >= p_quantity THEN
        UPDATE books SET available_copies = available_copies - p_quantity WHERE book_id = p_book_id;
        INSERT INTO book_loans (book_id, student_number, quantity) VALUES (p_book_id, p_student_number, p_quantity);
        RAISE NOTICE 'Loan successful for %', p_student_number;
    ELSE
        RAISE NOTICE 'Loan FAILED: only % available for book %', v_available, p_book_id;
    END IF;
END $$;

-- 5. Call borrow_book - 2 valid + 1 exceeding
CALL borrow_book(1, '202410672', 2);
CALL borrow_book(2, '202410001', 1);
CALL borrow_book(2, '202410002', 5); -- exceeds

SELECT * FROM books;
SELECT * FROM book_loans;

-- 6. return_book procedure
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_book_id INT; v_quantity INT; v_status VARCHAR;
BEGIN
    SELECT book_id, quantity, loan_status INTO v_book_id, v_quantity, v_status FROM book_loans WHERE loan_id = p_loan_id;
    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % already returned - will NOT restore again', p_loan_id;
    ELSE
        UPDATE book_loans SET loan_status = 'RETURNED', return_date = CURRENT_DATE WHERE loan_id = p_loan_id;
        UPDATE books SET available_copies = available_copies + v_quantity WHERE book_id = v_book_id;
        RAISE NOTICE 'Loan % returned', p_loan_id;
    END IF;
END $$;

CALL return_book(1);
CALL return_book(1); -- second call test

-- 7. Explicit cursor for few copies
DO $$
DECLARE c_low CURSOR FOR SELECT book_id, title, available_copies FROM books WHERE available_copies <= 2;
    r RECORD;
BEGIN
    OPEN c_low;
    LOOP FETCH c_low INTO r; EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: % has % copies', r.title, r.available_copies;
    END LOOP;
    CLOSE c_low;
END $$;

-- 8. Zero copies with EXCEPTION
DO $$
BEGIN
    CALL borrow_book(1, '202410999', 0);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Handled: %', SQLERRM;
END $$;

-- 9. Final queries
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;