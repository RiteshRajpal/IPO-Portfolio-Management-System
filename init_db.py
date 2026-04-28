"""
Database Initialization Script
Reads MySQL password from .env and sets up complete database
"""
import MySQLdb
import os
from dotenv import load_dotenv
from flask_bcrypt import Bcrypt

load_dotenv()

bcrypt = Bcrypt()

# Get credentials from .env
MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
MYSQL_USER = os.getenv('MYSQL_USER', 'root')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD')
MYSQL_DB = os.getenv('MYSQL_DB', 'ipo_management_system')

print("🔧 Initializing Database...")
print(f"Host: {MYSQL_HOST}")
print(f"User: {MYSQL_USER}")
print(f"Database: {MYSQL_DB}")

try:
    # Connect without database first
    conn = MySQLdb.connect(
        host=MYSQL_HOST,
        user=MYSQL_USER,
        passwd=MYSQL_PASSWORD
    )
    cursor = conn.cursor()
    
    # Create database
    print(f"\n📦 Creating database '{MYSQL_DB}'...")
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {MYSQL_DB}")
    cursor.execute(f"USE {MYSQL_DB}")
    
    # Drop existing tables
    print("🗑️  Dropping existing tables...")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
    tables = ['wallet_transactions', 'portfolio', 'allotment', 'ipo_application', 'ipo', 'users', 'admin']
    for table in tables:
        cursor.execute(f"DROP TABLE IF EXISTS {table}")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
    
    # Create tables
    print("📋 Creating tables...")
    
    # Users table
    cursor.execute("""
        CREATE TABLE users (
            user_id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            email VARCHAR(100) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            balance DECIMAL(15, 2) DEFAULT 0.00,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Admin table
    cursor.execute("""
        CREATE TABLE admin (
            admin_id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(50) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # IPO table
    cursor.execute("""
        CREATE TABLE ipo (
            ipo_id INT AUTO_INCREMENT PRIMARY KEY,
            company_name VARCHAR(100) NOT NULL,
            price_per_share DECIMAL(10, 2) NOT NULL,
            total_shares INT NOT NULL,
            available_shares INT NOT NULL,
            open_date DATE NOT NULL,
            close_date DATE NOT NULL,
            status ENUM('OPEN', 'CLOSED') DEFAULT 'OPEN',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # IPO Application table
    cursor.execute("""
        CREATE TABLE ipo_application (
            application_id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            ipo_id INT NOT NULL,
            shares_applied INT NOT NULL,
            status ENUM('PENDING', 'APPROVED', 'REJECTED') DEFAULT 'PENDING',
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (ipo_id) REFERENCES ipo(ipo_id) ON DELETE CASCADE
        )
    """)
    
    # Allotment table
    cursor.execute("""
        CREATE TABLE allotment (
            allotment_id INT AUTO_INCREMENT PRIMARY KEY,
            application_id INT NOT NULL,
            shares_allotted INT NOT NULL,
            allotted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (application_id) REFERENCES ipo_application(application_id) ON DELETE CASCADE
        )
    """)
    
    # Portfolio table
    cursor.execute("""
        CREATE TABLE portfolio (
            portfolio_id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            ipo_id INT NOT NULL,
            shares_owned INT NOT NULL,
            average_price DECIMAL(10, 2) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (ipo_id) REFERENCES ipo(ipo_id) ON DELETE CASCADE
        )
    """)
    
    # Wallet Transactions table
    cursor.execute("""
        CREATE TABLE wallet_transactions (
            transaction_id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            type VARCHAR(50) NOT NULL,
            amount DECIMAL(15, 2) NOT NULL,
            transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
        )
    """)
    
    # Add indexes
    print("🔍 Creating indexes...")
    cursor.execute("CREATE INDEX idx_user_transactions ON wallet_transactions(user_id, transaction_date DESC)")
    cursor.execute("CREATE INDEX idx_portfolio_user ON portfolio(user_id)")
    cursor.execute("CREATE INDEX idx_applications_user ON ipo_application(user_id)")
    cursor.execute("CREATE INDEX idx_applications_status ON ipo_application(status)")
    
    # Insert sample data
    print("📝 Inserting sample data...")
    
    # Admin (password: Admin@123456)
    admin_pass = bcrypt.generate_password_hash('Admin@123456').decode('utf-8')
    cursor.execute("INSERT INTO admin (username, password) VALUES (%s, %s)", ('admin', admin_pass))
    
    # Test users (password: Test@123456)
    test_pass = bcrypt.generate_password_hash('Test@123456').decode('utf-8')
    cursor.execute("""
        INSERT INTO users (name, email, password, balance) VALUES 
        ('Test User', 'test@example.com', %s, 100000.00),
        ('Demo User', 'demo@example.com', %s, 50000.00)
    """, (test_pass, test_pass))
    
    # Sample IPOs
    cursor.execute("""
        INSERT INTO ipo (company_name, price_per_share, total_shares, available_shares, open_date, close_date, status) VALUES
        ('Reliance Industries', 2500.00, 10000, 10000, '2026-05-01', '2026-05-10', 'OPEN'),
        ('Tata Motors', 450.00, 20000, 20000, '2026-05-05', '2026-05-15', 'OPEN'),
        ('Infosys', 1800.00, 15000, 15000, '2026-05-03', '2026-05-12', 'OPEN'),
        ('HDFC Bank', 1650.00, 12000, 12000, '2026-05-07', '2026-05-17', 'OPEN'),
        ('Wipro', 420.00, 18000, 18000, '2026-05-02', '2026-05-11', 'OPEN')
    """)
    
    conn.commit()
    
    print("\n✅ Database initialized successfully!")
    print("\n🔑 Test Credentials:")
    print("=" * 50)
    print("ADMIN LOGIN:")
    print("  Username: admin")
    print("  Password: Admin@123456")
    print("\nUSER LOGIN:")
    print("  Email: test@example.com")
    print("  Password: Test@123456")
    print("  Balance: ₹100,000")
    print("\nALTERNATE USER:")
    print("  Email: demo@example.com")
    print("  Password: Test@123456")
    print("  Balance: ₹50,000")
    print("=" * 50)
    
    cursor.close()
    conn.close()
    
except MySQLdb.Error as e:
    print(f"\n❌ Error: {e}")
    print("\nMake sure:")
    print("1. MySQL is running")
    print("2. Password in .env is correct")
    print("3. User has proper permissions")
except Exception as e:
    print(f"\n❌ Unexpected error: {e}")
