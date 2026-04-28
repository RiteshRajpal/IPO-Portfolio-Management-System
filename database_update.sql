-- Run this to add any missing columns or tables for new features
USE ipo_management_system;

-- Ensure wallet_transactions table exists
CREATE TABLE IF NOT EXISTS wallet_transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Add index for better performance
CREATE INDEX idx_user_transactions ON wallet_transactions(user_id, transaction_date DESC);
CREATE INDEX idx_portfolio_user ON portfolio(user_id);
CREATE INDEX idx_applications_user ON ipo_application(user_id);
CREATE INDEX idx_applications_status ON ipo_application(status);

-- Update existing users with some balance if they have 0
UPDATE users SET balance = 50000.00 WHERE balance = 0;

-- Ensure admin exists
INSERT IGNORE INTO admin (username, password) VALUES ('admin', 'admin123');

SELECT 'Database updated successfully!' as message;
