-- ============================================================
-- IPO MANAGEMENT SYSTEM - MySQL Database Schema
-- ============================================================
-- This file creates the complete database, all tables,
-- relationships (foreign keys), indexes, triggers, stored
-- procedures, and inserts sample data for testing.
-- ============================================================

-- ==================== DATABASE ====================
CREATE DATABASE IF NOT EXISTS ipo_management_system;
USE ipo_management_system;


-- ============================================================
-- TABLE 1: admin
-- Stores admin credentials for the admin panel
-- ============================================================
CREATE TABLE IF NOT EXISTS admin (
    admin_id    INT             AUTO_INCREMENT PRIMARY KEY,
    username    VARCHAR(50)     NOT NULL UNIQUE,
    password    VARCHAR(255)    NOT NULL,
    created_at  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 2: users
-- Stores registered user details and wallet balance
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    user_id     INT             AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100)    NOT NULL,
    email       VARCHAR(100)    NOT NULL UNIQUE,
    password    VARCHAR(255)    NOT NULL,
    balance     DECIMAL(15,2)   DEFAULT 10000.00,
    created_at  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 3: ipo
-- Stores IPO listings added by admin
-- ============================================================
CREATE TABLE IF NOT EXISTS ipo (
    ipo_id              INT             AUTO_INCREMENT PRIMARY KEY,
    company_name        VARCHAR(150)    NOT NULL,
    price_per_share     DECIMAL(10,2)   NOT NULL,
    total_shares        INT             NOT NULL,
    available_shares    INT             NOT NULL,
    open_date           DATE            NOT NULL,
    close_date          DATE            NOT NULL,
    status              ENUM('OPEN','CLOSED') DEFAULT 'OPEN',
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 4: ipo_application
-- Stores user applications for IPOs
-- ============================================================
CREATE TABLE IF NOT EXISTS ipo_application (
    application_id  INT             AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    ipo_id          INT             NOT NULL,
    shares_applied  INT             NOT NULL,
    status          ENUM('PENDING','APPROVED','REJECTED') DEFAULT 'PENDING',
    applied_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ipo_id) REFERENCES ipo(ipo_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 5: allotment
-- Stores share allotments after admin approves an application
-- ============================================================
CREATE TABLE IF NOT EXISTS allotment (
    allotment_id    INT             AUTO_INCREMENT PRIMARY KEY,
    application_id  INT             NOT NULL,
    shares_allotted INT             NOT NULL,
    allotted_at     TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (application_id) REFERENCES ipo_application(application_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 6: portfolio
-- Stores the shares owned by each user per IPO
-- ============================================================
CREATE TABLE IF NOT EXISTS portfolio (
    portfolio_id    INT             AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    ipo_id          INT             NOT NULL,
    shares_owned    INT             NOT NULL DEFAULT 0,
    average_price   DECIMAL(10,2)   NOT NULL DEFAULT 0.00,

    UNIQUE KEY uq_user_ipo (user_id, ipo_id),

    FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ipo_id) REFERENCES ipo(ipo_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 7: wallet_transactions
-- Logs every wallet debit (IPO purchases)
-- ============================================================
CREATE TABLE IF NOT EXISTS wallet_transactions (
    transaction_id  INT             AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    type            VARCHAR(50)     NOT NULL,
    amount          DECIMAL(15,2)   NOT NULL,
    transaction_at  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 8: wallet_requests
-- Stores user requests to add money (requires admin approval)
-- ============================================================
CREATE TABLE IF NOT EXISTS wallet_requests (
    request_id      INT             AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             NOT NULL,
    amount          DECIMAL(15,2)   NOT NULL,
    status          ENUM('PENDING','APPROVED','REJECTED') DEFAULT 'PENDING',
    request_date    TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- TABLE 9: price_history
-- Tracks IPO price changes over time (used for chart/graph)
-- ============================================================
CREATE TABLE IF NOT EXISTS price_history (
    price_id    INT             AUTO_INCREMENT PRIMARY KEY,
    ipo_id      INT             NOT NULL,
    price       DECIMAL(10,2)   NOT NULL,
    share_price DECIMAL(10,2)   NOT NULL,
    trade_date  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ipo_id) REFERENCES ipo(ipo_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================
-- INDEXES for performance optimization
-- ============================================================
CREATE INDEX idx_ipo_app_user    ON ipo_application(user_id);
CREATE INDEX idx_ipo_app_ipo     ON ipo_application(ipo_id);
CREATE INDEX idx_ipo_app_status  ON ipo_application(status);
CREATE INDEX idx_portfolio_user  ON portfolio(user_id);
CREATE INDEX idx_wallet_txn_user ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_req_user ON wallet_requests(user_id);
CREATE INDEX idx_wallet_req_stat ON wallet_requests(status);
CREATE INDEX idx_price_hist_ipo  ON price_history(ipo_id);
CREATE INDEX idx_users_email     ON users(email);


-- ============================================================
-- STORED PROCEDURE: sp_approve_application
-- Admin approves an IPO application with share allotment.
-- Handles: validation, allotment, balance deduction,
--          wallet log, and portfolio update in one transaction.
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_approve_application(
    IN p_application_id INT,
    IN p_shares         INT
)
BEGIN
    DECLARE v_applied_shares    INT;
    DECLARE v_ipo_id            INT;
    DECLARE v_user_id           INT;
    DECLARE v_available         INT;
    DECLARE v_price             DECIMAL(10,2);
    DECLARE v_total_cost        DECIMAL(15,2);
    DECLARE v_user_balance      DECIMAL(15,2);
    DECLARE v_existing_portfolio INT DEFAULT 0;

    -- Start transaction
    START TRANSACTION;

    -- 1. Get application details
    SELECT shares_applied, ipo_id, user_id
    INTO v_applied_shares, v_ipo_id, v_user_id
    FROM ipo_application
    WHERE application_id = p_application_id AND status = 'PENDING'
    FOR UPDATE;

    IF v_applied_shares IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid or already processed application';
    END IF;

    -- 2. Validate shares
    IF p_shares > v_applied_shares THEN
        SIGNAL SQLSTATE '45001'
        SET MESSAGE_TEXT = 'Cannot approve more than applied shares';
    END IF;

    -- 3. Get IPO details
    SELECT available_shares, price_per_share
    INTO v_available, v_price
    FROM ipo WHERE ipo_id = v_ipo_id FOR UPDATE;

    IF p_shares > v_available THEN
        SIGNAL SQLSTATE '45002'
        SET MESSAGE_TEXT = 'Not enough IPO shares available';
    END IF;

    -- 4. Calculate cost & check user balance
    SET v_total_cost = p_shares * v_price;

    SELECT balance INTO v_user_balance
    FROM users WHERE user_id = v_user_id FOR UPDATE;

    IF v_user_balance < v_total_cost THEN
        SIGNAL SQLSTATE '45003'
        SET MESSAGE_TEXT = 'Insufficient user wallet balance';
    END IF;

    -- 5. Insert allotment
    INSERT INTO allotment (application_id, shares_allotted)
    VALUES (p_application_id, p_shares);

    -- 6. Update application status
    UPDATE ipo_application
    SET status = 'APPROVED'
    WHERE application_id = p_application_id;

    -- 7. Reduce available IPO shares
    UPDATE ipo
    SET available_shares = available_shares - p_shares
    WHERE ipo_id = v_ipo_id;

    -- 8. Deduct user balance
    UPDATE users
    SET balance = balance - v_total_cost
    WHERE user_id = v_user_id;

    -- 9. Log wallet transaction
    INSERT INTO wallet_transactions (user_id, type, amount)
    VALUES (v_user_id, 'IPO Purchase', v_total_cost);

    -- 10. Update or insert portfolio
    SELECT COUNT(*) INTO v_existing_portfolio
    FROM portfolio
    WHERE user_id = v_user_id AND ipo_id = v_ipo_id;

    IF v_existing_portfolio > 0 THEN
        UPDATE portfolio
        SET shares_owned = shares_owned + p_shares
        WHERE user_id = v_user_id AND ipo_id = v_ipo_id;
    ELSE
        INSERT INTO portfolio (user_id, ipo_id, shares_owned, average_price)
        VALUES (v_user_id, v_ipo_id, p_shares, v_price);
    END IF;

    -- 11. Commit
    COMMIT;

END //

DELIMITER ;


-- ============================================================
-- STORED PROCEDURE: sp_apply_ipo
-- User applies for an IPO with transactional safety (ACID).
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_apply_ipo(
    IN p_user_id    INT,
    IN p_ipo_id     INT,
    IN p_shares     INT
)
BEGIN
    DECLARE v_price             DECIMAL(10,2);
    DECLARE v_available_shares  INT;
    DECLARE v_total_cost        DECIMAL(15,2);
    DECLARE v_user_balance      DECIMAL(15,2);

    START TRANSACTION;

    -- 1. Lock & fetch IPO
    SELECT price_per_share, available_shares
    INTO v_price, v_available_shares
    FROM ipo WHERE ipo_id = p_ipo_id FOR UPDATE;

    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'IPO not found';
    END IF;

    SET v_total_cost = v_price * p_shares;

    -- 2. Lock & fetch user balance
    SELECT balance INTO v_user_balance
    FROM users WHERE user_id = p_user_id FOR UPDATE;

    IF v_user_balance IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;

    -- 3. Validations
    IF p_shares <= 0 THEN
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = 'Invalid share quantity';
    END IF;

    IF p_shares > v_available_shares THEN
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = 'Not enough shares available';
    END IF;

    IF v_total_cost > v_user_balance THEN
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = 'Insufficient wallet balance';
    END IF;

    -- 4. Deduct user balance
    UPDATE users
    SET balance = balance - v_total_cost
    WHERE user_id = p_user_id;

    -- 5. Reduce available IPO shares
    UPDATE ipo
    SET available_shares = available_shares - p_shares
    WHERE ipo_id = p_ipo_id;

    -- 6. Insert application
    INSERT INTO ipo_application (user_id, ipo_id, shares_applied, status)
    VALUES (p_user_id, p_ipo_id, p_shares, 'PENDING');

    COMMIT;

END //

DELIMITER ;


-- ============================================================
-- STORED PROCEDURE: sp_approve_wallet_request
-- Admin approves a wallet balance request.
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_approve_wallet_request(
    IN p_request_id INT
)
BEGIN
    DECLARE v_user_id   INT;
    DECLARE v_amount    DECIMAL(15,2);
    DECLARE v_status    VARCHAR(20);

    START TRANSACTION;

    SELECT user_id, amount, status
    INTO v_user_id, v_amount, v_status
    FROM wallet_requests
    WHERE request_id = p_request_id FOR UPDATE;

    IF v_status != 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Request is not pending';
    END IF;

    -- Add balance to user
    UPDATE users
    SET balance = balance + v_amount
    WHERE user_id = v_user_id;

    -- Mark request as approved
    UPDATE wallet_requests
    SET status = 'APPROVED'
    WHERE request_id = p_request_id;

    COMMIT;

END //

DELIMITER ;


-- ============================================================
-- TRIGGER: trg_price_history_sync
-- When a new price is inserted into price_history,
-- automatically keep both price and share_price in sync.
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_price_history_sync
BEFORE INSERT ON price_history
FOR EACH ROW
BEGIN
    IF NEW.share_price = 0 AND NEW.price > 0 THEN
        SET NEW.share_price = NEW.price;
    ELSEIF NEW.price = 0 AND NEW.share_price > 0 THEN
        SET NEW.price = NEW.share_price;
    END IF;
END //

DELIMITER ;


-- ============================================================
-- VIEWS for convenient data retrieval
-- ============================================================

-- View: All applications with user and IPO names
CREATE OR REPLACE VIEW vw_applications AS
SELECT
    ia.application_id,
    u.name          AS user_name,
    u.email         AS user_email,
    i.company_name,
    i.price_per_share,
    ia.shares_applied,
    ia.status,
    ia.applied_at
FROM ipo_application ia
JOIN users u ON ia.user_id = u.user_id
JOIN ipo i   ON ia.ipo_id  = i.ipo_id
ORDER BY ia.application_id DESC;


-- View: Wallet requests with user names
CREATE OR REPLACE VIEW vw_wallet_requests AS
SELECT
    wr.request_id,
    u.name          AS user_name,
    wr.amount,
    wr.status,
    wr.request_date
FROM wallet_requests wr
JOIN users u ON wr.user_id = u.user_id
ORDER BY wr.request_date DESC;


-- View: User portfolio with company names
CREATE OR REPLACE VIEW vw_portfolio AS
SELECT
    p.portfolio_id,
    u.name          AS user_name,
    i.company_name,
    p.shares_owned,
    p.average_price,
    (p.shares_owned * p.average_price) AS total_value
FROM portfolio p
JOIN users u ON p.user_id = u.user_id
JOIN ipo i   ON p.ipo_id  = i.ipo_id;


-- ============================================================
-- SAMPLE DATA - For testing purposes
-- ============================================================

-- Default Admin Account (username: admin, password: admin123)
INSERT INTO admin (username, password)
VALUES ('admin', 'admin123');

-- Sample Users (password stored as plain text, matching original PHP)
INSERT INTO users (name, email, password, balance) VALUES
('Rahul Sharma',    'rahul@example.com',    'password123',  10000.00),
('Priya Patel',     'priya@example.com',    'password123',  15000.00),
('Amit Kumar',      'amit@example.com',     'password123',  20000.00);

-- Sample IPOs
INSERT INTO ipo (company_name, price_per_share, total_shares, available_shares, open_date, close_date, status) VALUES
('Tata Technologies',  500.00,  10000, 8000,  '2026-05-01', '2026-05-15', 'OPEN'),
('Reliance Jio',       750.00,  20000, 15000, '2026-05-05', '2026-05-20', 'OPEN'),
('Zomato Ltd',         120.00,  50000, 40000, '2026-04-20', '2026-05-10', 'OPEN'),
('Paytm Digital',      350.00,  15000, 12000, '2026-05-10', '2026-05-25', 'OPEN');

-- Sample Price History
INSERT INTO price_history (ipo_id, price, share_price, trade_date) VALUES
(1, 480.00, 480.00, '2026-04-20 10:00:00'),
(1, 495.00, 495.00, '2026-04-21 10:00:00'),
(1, 500.00, 500.00, '2026-04-22 10:00:00'),
(1, 510.00, 510.00, '2026-04-23 10:00:00'),
(1, 525.00, 525.00, '2026-04-24 10:00:00'),
(2, 730.00, 730.00, '2026-04-20 10:00:00'),
(2, 740.00, 740.00, '2026-04-21 10:00:00'),
(2, 750.00, 750.00, '2026-04-22 10:00:00'),
(2, 745.00, 745.00, '2026-04-23 10:00:00'),
(2, 760.00, 760.00, '2026-04-24 10:00:00'),
(3, 115.00, 115.00, '2026-04-20 10:00:00'),
(3, 118.00, 118.00, '2026-04-21 10:00:00'),
(3, 120.00, 120.00, '2026-04-22 10:00:00'),
(3, 122.00, 122.00, '2026-04-23 10:00:00'),
(3, 119.00, 119.00, '2026-04-24 10:00:00');

-- Sample IPO Applications
INSERT INTO ipo_application (user_id, ipo_id, shares_applied, status) VALUES
(1, 1, 100, 'PENDING'),
(1, 3, 500, 'APPROVED'),
(2, 2, 200, 'PENDING'),
(3, 1, 150, 'APPROVED');

-- Sample Allotments (for approved applications)
INSERT INTO allotment (application_id, shares_allotted) VALUES
(2, 500),
(4, 150);

-- Sample Portfolio (for approved applications)
INSERT INTO portfolio (user_id, ipo_id, shares_owned, average_price) VALUES
(1, 3, 500, 120.00),
(3, 1, 150, 500.00);

-- Sample Wallet Transactions
INSERT INTO wallet_transactions (user_id, type, amount) VALUES
(1, 'IPO Purchase', 60000.00),
(3, 'IPO Purchase', 75000.00);

-- Sample Wallet Requests
INSERT INTO wallet_requests (user_id, amount, status) VALUES
(1, 50000.00, 'PENDING'),
(2, 25000.00, 'APPROVED');


-- ============================================================
-- USEFUL QUERIES (for reference)
-- ============================================================

-- Get all pending applications:
-- SELECT * FROM vw_applications WHERE status = 'PENDING';

-- Get dashboard statistics:
-- SELECT
--     COUNT(*) AS total_applications,
--     SUM(CASE WHEN status = 'APPROVED' THEN 1 ELSE 0 END) AS approved,
--     SUM(CASE WHEN status = 'PENDING'  THEN 1 ELSE 0 END) AS pending
-- FROM ipo_application;

-- Get user portfolio:
-- SELECT * FROM vw_portfolio WHERE user_name = 'Rahul Sharma';

-- Get price history for chart:
-- SELECT share_price, trade_date FROM price_history
-- WHERE ipo_id = 1 ORDER BY trade_date ASC;

-- Approve an application using stored procedure:
-- CALL sp_approve_application(1, 100);

-- Apply for an IPO using stored procedure:
-- CALL sp_apply_ipo(1, 2, 200);

-- Approve a wallet request:
-- CALL sp_approve_wallet_request(1);
