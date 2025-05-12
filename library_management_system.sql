-- Library Management System Database
-- Created by: Michael Calvin Omondi
-- Date: 10th May 2025

-- Create database
CREATE DATABASE library_management;
USE library_management;

-- Members table
CREATE TABLE members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address VARCHAR(200),
    date_of_birth DATE,
    membership_date DATE NOT NULL,
    membership_status ENUM('active', 'expired', 'suspended') NOT NULL DEFAULT 'active'
);

-- Authors table
CREATE TABLE authors (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_year INT,
    death_year INT,
    nationality VARCHAR(50),
    biography TEXT
);

-- Publishers table
CREATE TABLE publishers (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    publisher_name VARCHAR(100) NOT NULL UNIQUE,
    address VARCHAR(200),
    phone VARCHAR(20),
    email VARCHAR(100),
    website VARCHAR(100),
    founded_year INT
);

-- Categories table
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- Books table
CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(20) UNIQUE NOT NULL,
    title VARCHAR(200) NOT NULL,
    publisher_id INT,
    publication_year INT,
    edition INT DEFAULT 1,
    page_count INT,
    language VARCHAR(30),
    description TEXT,
    cover_image VARCHAR(255),
    stock_quantity INT NOT NULL DEFAULT 1,
    available_quantity INT NOT NULL DEFAULT 1,
    location VARCHAR(50),
    CONSTRAINT fk_book_publisher FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id)
);

-- Book-Author relationship
CREATE TABLE book_authors (
    book_id INT NOT NULL,
    author_id INT NOT NULL,
    PRIMARY KEY (book_id, author_id),
    CONSTRAINT fk_ba_book FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    CONSTRAINT fk_ba_author FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);

-- Book-Category relationship
CREATE TABLE book_categories (
    book_id INT NOT NULL,
    category_id INT NOT NULL,
    PRIMARY KEY (book_id, category_id),
    CONSTRAINT fk_bc_book FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    CONSTRAINT fk_bc_category FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- Loans table
CREATE TABLE loans (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    member_id INT NOT NULL,
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    status ENUM('on loan', 'returned', 'overdue', 'lost') NOT NULL DEFAULT 'on loan',
    CONSTRAINT fk_loan_book FOREIGN KEY (book_id) REFERENCES books(book_id),
    CONSTRAINT fk_loan_member FOREIGN KEY (member_id) REFERENCES members(member_id)
);

-- Fines table
CREATE TABLE fines (
    fine_id INT AUTO_INCREMENT PRIMARY KEY,
    loan_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    issue_date DATE NOT NULL,
    payment_date DATE,
    status ENUM('outstanding', 'paid', 'waived') NOT NULL DEFAULT 'outstanding',
    CONSTRAINT fk_fine_loan FOREIGN KEY (loan_id) REFERENCES loans(loan_id)
);

-- Reservations table
CREATE TABLE reservations (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    member_id INT NOT NULL,
    reservation_date DATETIME NOT NULL,
    expiry_date DATETIME NOT NULL,
    status ENUM('pending', 'fulfilled', 'cancelled', 'expired') NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_reservation_book FOREIGN KEY (book_id) REFERENCES books(book_id),
    CONSTRAINT fk_reservation_member FOREIGN KEY (member_id) REFERENCES members(member_id)
);

-- Staff table
CREATE TABLE staff (
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address VARCHAR(200),
    position VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    salary DECIMAL(10,2)
);

-- Indexes
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_members_name ON members(last_name, first_name);
CREATE INDEX idx_authors_name ON authors(last_name, first_name);
CREATE INDEX idx_loans_dates ON loans(loan_date, due_date, return_date);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_fines_status ON fines(status);
CREATE INDEX idx_reservations_status ON reservations(status);

-- Views
CREATE VIEW available_books AS
SELECT b.book_id, b.title, b.isbn, GROUP_CONCAT(DISTINCT CONCAT(a.first_name, ' ', a.last_name) SEPARATOR ', ') AS authors,
       GROUP_CONCAT(DISTINCT c.category_name SEPARATOR ', ') AS categories, b.available_quantity
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id
LEFT JOIN authors a ON ba.author_id = a.author_id
LEFT JOIN book_categories bc ON b.book_id = bc.book_id
LEFT JOIN categories c ON bc.category_id = c.category_id
WHERE b.available_quantity > 0
GROUP BY b.book_id;

CREATE VIEW checked_out_books AS
SELECT l.loan_id, b.book_id, b.title, b.isbn, 
       CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       l.loan_date, l.due_date, DATEDIFF(l.due_date, CURRENT_DATE) AS days_remaining,
       CASE WHEN l.due_date < CURRENT_DATE AND l.return_date IS NULL 
            THEN DATEDIFF(CURRENT_DATE, l.due_date) ELSE 0 END AS days_overdue
FROM loans l
JOIN books b ON l.book_id = b.book_id
JOIN members m ON l.member_id = m.member_id
WHERE l.return_date IS NULL;

CREATE VIEW overdue_books AS
SELECT * FROM checked_out_books
WHERE days_overdue > 0;

-- Stored Procedures
DELIMITER //
CREATE PROCEDURE borrow_book(IN p_book_id INT, IN p_member_id INT, OUT p_result VARCHAR(200))
BEGIN
    DECLARE v_available INT;
    DECLARE v_active_membership INT;
    DECLARE v_overdue_books INT;
    DECLARE v_max_loans INT DEFAULT 5;
    
    -- Check if member exists and has active membership
    SELECT COUNT(*) INTO v_active_membership
    FROM members
    WHERE member_id = p_member_id AND membership_status = 'active';
    
    IF v_active_membership = 0 THEN
        SET p_result = 'Error: Member does not exist or membership is not active';
    ELSE
        -- Check if member has overdue books
        SELECT COUNT(*) INTO v_overdue_books
        FROM loans
        WHERE member_id = p_member_id AND return_date IS NULL AND due_date < CURRENT_DATE;
        
        IF v_overdue_books > 0 THEN
            SET p_result = 'Error: Member has overdue books and cannot borrow more';
        ELSE
            -- Check how many books member currently has checked out
            SELECT COUNT(*) INTO v_overdue_books
            FROM loans
            WHERE member_id = p_member_id AND return_date IS NULL;
            
            IF v_overdue_books >= v_max_loans THEN
                SET p_result = CONCAT('Error: Member has reached maximum loan limit of ', v_max_loans);
            ELSE
                -- Check book availability
                SELECT available_quantity INTO v_available
                FROM books
                WHERE book_id = p_book_id;
                
                IF v_available IS NULL THEN
                    SET p_result = 'Error: Book does not exist';
                ELSEIF v_available <= 0 THEN
                    SET p_result = 'Error: Book is not available for loan';
                ELSE
                    -- Create loan record
                    INSERT INTO loans (book_id, member_id, loan_date, due_date, status)
                    VALUES (p_book_id, p_member_id, CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY), 'on loan');
                    
                    -- Update book availability
                    UPDATE books
                    SET available_quantity = available_quantity - 1
                    WHERE book_id = p_book_id;
                    
                    SET p_result = 'Book successfully borrowed';
                END IF;
            END IF;
        END IF;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE return_book(IN p_loan_id INT, OUT p_result VARCHAR(200))
BEGIN
    DECLARE v_book_id INT;
    DECLARE v_returned INT;
    DECLARE v_due_date DATE;
    
    -- Check if loan exists and is not already returned
    SELECT book_id, return_date, due_date INTO v_book_id, v_returned, v_due_date
    FROM loans
    WHERE loan_id = p_loan_id;
    
    IF v_book_id IS NULL THEN
        SET p_result = 'Error: Loan record not found';
    ELSEIF v_returned IS NOT NULL THEN
        SET p_result = 'Error: Book already returned';
    ELSE
        -- Update loan record
        UPDATE loans
        SET return_date = CURRENT_DATE,
            status = CASE WHEN v_due_date < CURRENT_DATE THEN 'overdue' ELSE 'returned' END
        WHERE loan_id = p_loan_id;
        
        -- Update book availability
        UPDATE books
        SET available_quantity = available_quantity + 1
        WHERE book_id = v_book_id;
        
        -- Check if overdue and create fine if needed
        IF v_due_date < CURRENT_DATE THEN
            INSERT INTO fines (loan_id, amount, issue_date, status)
            VALUES (p_loan_id, DATEDIFF(CURRENT_DATE, v_due_date) * 0.50, CURRENT_DATE, 'outstanding');
        END IF;
        
        SET p_result = 'Book successfully returned';
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE search_books(
    IN p_search_term VARCHAR(100),
    IN p_author_name VARCHAR(100),
    IN p_category_name VARCHAR(50),
    IN p_only_available BOOLEAN
)
BEGIN
    SELECT b.book_id, b.title, b.isbn, 
           GROUP_CONCAT(DISTINCT CONCAT(a.first_name, ' ', a.last_name) SEPARATOR ', ') AS authors,
           GROUP_CONCAT(DISTINCT c.category_name SEPARATOR ', ') AS categories,
           b.available_quantity, b.stock_quantity
    FROM books b
    LEFT JOIN book_authors ba ON b.book_id = ba.book_id
    LEFT JOIN authors a ON ba.author_id = a.author_id
    LEFT JOIN book_categories bc ON b.book_id = bc.book_id
    LEFT JOIN categories c ON bc.category_id = c.category_id
    WHERE (p_search_term IS NULL OR 
           b.title LIKE CONCAT('%', p_search_term, '%') OR 
           b.isbn LIKE CONCAT('%', p_search_term, '%'))
    AND (p_author_name IS NULL OR 
         CONCAT(a.first_name, ' ', a.last_name) LIKE CONCAT('%', p_author_name, '%'))
    AND (p_category_name IS NULL OR c.category_name LIKE CONCAT('%', p_category_name, '%'))
    AND (NOT p_only_available OR b.available_quantity > 0)
    GROUP BY b.book_id;
END //
DELIMITER ;

-- Triggers
DELIMITER //
CREATE TRIGGER after_loan_insert
AFTER INSERT ON loans
FOR EACH ROW
BEGIN
    UPDATE books
    SET available_quantity = available_quantity - 1
    WHERE book_id = NEW.book_id;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER after_loan_update
AFTER UPDATE ON loans
FOR EACH ROW
BEGIN
    IF OLD.return_date IS NULL AND NEW.return_date IS NOT NULL THEN
        UPDATE books
        SET available_quantity = available_quantity + 1
        WHERE book_id = NEW.book_id;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER before_book_delete
BEFORE DELETE ON books
FOR EACH ROW
BEGIN
    DECLARE v_active_loans INT;
    
    SELECT COUNT(*) INTO v_active_loans
    FROM loans
    WHERE book_id = OLD.book_id AND return_date IS NULL;
    
    IF v_active_loans > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete book with active loans';
    END IF;
END //
DELIMITER ;

-- Sample Data
INSERT INTO categories (category_name, description) VALUES
('Fiction', 'Imaginative narrative that is not based on real events'),
('Non-Fiction', 'Prose writing that is based on facts, real events, and real people'),
('Science Fiction', 'Fiction dealing with futuristic concepts, space travel, time travel, etc.'),
('Mystery', 'Fiction dealing with the solution of a crime or puzzle'),
('Biography', 'Non-fiction account of a person''s life');

INSERT INTO publishers (publisher_name, address, phone, email, website, founded_year) VALUES
('Penguin Random House', '1745 Broadway, New York, NY 10019', '212-782-9000', 'info@penguinrandomhouse.com', 'https://www.penguinrandomhouse.com', 2013),
('HarperCollins', '195 Broadway, New York, NY 10007', '212-207-7000', 'info@harpercollins.com', 'https://www.harpercollins.com', 1989),
('Simon & Schuster', '1230 Avenue of the Americas, New York, NY 10020', '212-698-7000', 'info@simonandschuster.com', 'https://www.simonandschuster.com', 1924);

INSERT INTO authors (first_name, last_name, birth_year, death_year, nationality, biography) VALUES
('George', 'Orwell', 1903, 1950, 'British', 'English novelist, essayist, journalist, and critic'),
('J.K.', 'Rowling', 1965, NULL, 'British', 'Author of the Harry Potter fantasy series'),
('Stephen', 'King', 1947, NULL, 'American', 'Author of horror, supernatural fiction, suspense, and fantasy novels'),
('Michelle', 'Obama', 1964, NULL, 'American', 'Lawyer, university administrator, and writer who served as first lady of the United States'),
('Agatha', 'Christie', 1890, 1976, 'British', 'Known for her detective novels and short story collections');

INSERT INTO books (isbn, title, publisher_id, publication_year, edition, page_count, language, description, stock_quantity, available_quantity, location) VALUES
('9780451524935', '1984', 1, 1949, 1, 328, 'English', 'A dystopian social science fiction novel and cautionary tale', 5, 5, 'A1'),
('9780439554930', 'Harry Potter and the Philosopher''s Stone', 2, 1997, 1, 223, 'English', 'The first novel in the Harry Potter series', 3, 3, 'B2'),
('9781501142970', 'It', 3, 1986, 1, 1138, 'English', 'A horror novel about an evil clown', 2, 2, 'C3'),
('9781524763138', 'Becoming', 1, 2018, 1, 448, 'English', 'Memoir by former First Lady Michelle Obama', 4, 4, 'D4'),
('9780062073501', 'Murder on the Orient Express', 2, 1934, 1, 256, 'English', 'A detective novel featuring Hercule Poirot', 3, 3, 'E5');

INSERT INTO book_authors (book_id, author_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 4), (5, 5);

INSERT INTO book_categories (book_id, category_id) VALUES
(1, 1), (1, 3), (2, 1), (2, 3), (3, 1), (3, 3), (4, 2), (4, 5), (5, 1), (5, 4);

INSERT INTO members (first_name, last_name, email, phone, address, date_of_birth, membership_date, membership_status) VALUES
('John', 'Omondi', 'john.o@gmail.com', '0715-0101', '123 Main St, Anytown, KE', '1985-06-15', '2025-01-15', 'active'),
('Jane', 'Anyango', 'jane.a@gmail.com', '0725-0102', '1234 Oak Ave, Somewhere, KE', '1990-03-22', '2025-05-10', 'active'),
('Robert', 'Ouko', 'robert.ou@gmail.com', '0735-0103', '12345 Pine Rd, Nowhere, KE', '1978-11-05', '2024-11-20', 'active'),
('Emily', 'Mwangi', 'emily.m@gmail.com', '0745-0104', '123456 Elm St, Anywhere, KE', '1995-07-30', '2025-02-28', 'suspended'),
('Michael', 'Nganga', 'michael.n@gmail.com', '0755-0105', '1234567 Maple Dr, Everywhere, KE', '1982-09-18', '2021-08-15', 'expired');

INSERT INTO staff (first_name, last_name, email, phone, address, position, hire_date, salary) VALUES
('Sarah', 'Nyambura', 'sarah.n@library.org', '07255-0201', '101 Library Lane, Booktown, KE', 'Librarian', '2017-04-10', 55000.00),
('David', 'Wafula', 'david.w@library.org', '073555-0202', '202 Reading Rd, Booktown, KE', 'Assistant Librarian', '2024-07-15', 42000.00),
('Lisa', 'Mwende', 'lisa.m@library.org', '074555-0203', '303 Shelf St, Booktown, KE', 'Library Technician', '2025-01-20', 38000.00);

INSERT INTO loans (book_id, member_id, loan_date, due_date, return_date, status) VALUES
(1, 1, '2025-01-10', '2025-01-24', '2025-01-22', 'returned'),
(2, 2, '2025-02-15', '2025-06-01', NULL, 'on loan'),
(3, 3, '202-03-20', '2025-04-03', '2025-04-05', 'overdue'),
(4, 1, '2025-05-05', '2025-05-19', NULL, 'on loan'),
(5, 4, '2025-05-10', '2025-05-24', NULL, 'on loan');

UPDATE books b
JOIN (
    SELECT book_id, COUNT(*) AS loaned_count
    FROM loans
    WHERE return_date IS NULL
    GROUP BY book_id
) l ON b.book_id = l.book_id
SET b.available_quantity = b.stock_quantity - l.loaned_count;

INSERT INTO fines (loan_id, amount, issue_date, payment_date, status) VALUES
(3, 1.00, '2025-04-06', NULL, 'outstanding');