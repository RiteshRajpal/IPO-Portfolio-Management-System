CREATE DATABASE IF NOT EXISTS ipo_management_system;
USE ipo_management_system;

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    balance DECIMAL(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Admin Table
CREATE TABLE IF NOT EXISTS admin (
    admin_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- IPO Table
CREATE TABLE IF NOT EXISTS ipo (
    ipo_id INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    price_per_share DECIMAL(10, 2) NOT NULL,
    total_shares INT NOT NULL,
    available_shares INT NOT NULL,
    open_date DATE NOT NULL,
    close_date DATE NOT NULL,
    status ENUM('OPEN', 'CLOSED') DEFAULT 'OPEN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- IPO Application Table
CREATE TABLE IF NOT EXISTS ipo_application (
    application_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    ipo_id INT NOT NULL,
    shares_applied INT NOT NULL,
    status ENUM('PENDING', 'APPROVED', 'REJECTED') DEFAULT 'PENDING',
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (ipo_id) REFERENCES ipo(ipo_id) ON DELETE CASCADE
);

-- Allotment Table
CREATE TABLE IF NOT EXISTS allotment (
    allotment_id INT AUTO_INCREMENT PRIMARY KEY,
    application_id INT NOT NULL,
    shares_allotted INT NOT NULL,
    allotted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES ipo_application(application_id) ON DELETE CASCADE
);

-- Portfolio Table
CREATE TABLE IF NOT EXISTS portfolio (
    portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    ipo_id INT NOT NULL,
    shares_owned INT NOT NULL,
    average_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (ipo_id) REFERENCES ipo(ipo_id) ON DELETE CASCADE
);

-- Wallet Transactions Table
CREATE TABLE IF NOT EXISTS wallet_transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Insert default admin
INSERT INTO admin (username, password) VALUES ('admin', 'admin123');

-- Insert sample users
INSERT INTO users (name, email, password, balance) VALUES 
('Tanish Poddar', 'tanish@example.com', 'password123', 50000.00),
('Rahul Sharma', 'rahul@example.com', 'password123', 30000.00);

-- Insert sample IPOs
INSERT INTO ipo (company_name, price_per_share, total_shares, available_shares, open_date, close_date, status) VALUES
('Reliance Industries', 2500.00, 10000, 10000, '2026-05-01', '2026-05-10', 'OPEN'),
('Tata Motors', 450.00, 20000, 20000, '2026-05-05', '2026-05-15', 'OPEN'),
('Infosys', 1800.00, 15000, 15000, '2026-05-03', '2026-05-12', 'OPEN');
