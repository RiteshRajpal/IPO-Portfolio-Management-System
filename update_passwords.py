"""
Script to update existing plain text passwords to hashed passwords
Run this once after updating to bcrypt
"""
from flask_bcrypt import Bcrypt
import MySQLdb
import os
from dotenv import load_dotenv

load_dotenv()

bcrypt = Bcrypt()

# Connect to database
conn = MySQLdb.connect(
    host=os.getenv('MYSQL_HOST'),
    user=os.getenv('MYSQL_USER'),
    passwd=os.getenv('MYSQL_PASSWORD'),
    db=os.getenv('MYSQL_DB')
)

cursor = conn.cursor()

# Get all users
cursor.execute("SELECT user_id, password FROM users")
users = cursor.fetchall()

print(f"Found {len(users)} users to update...")

for user_id, password in users:
    # Check if password is already hashed (bcrypt hashes start with $2b$)
    if not password.startswith('$2b$'):
        # Hash the password
        hashed = bcrypt.generate_password_hash(password).decode('utf-8')
        cursor.execute("UPDATE users SET password = %s WHERE user_id = %s", (hashed, user_id))
        print(f"Updated user ID: {user_id}")
    else:
        print(f"User ID {user_id} already has hashed password")

conn.commit()
cursor.close()
conn.close()

print("\n✅ Password update complete!")
print("All users can now login with their original passwords (now securely hashed)")
