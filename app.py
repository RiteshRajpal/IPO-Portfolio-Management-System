from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from flask_mysqldb import MySQL
from flask_bcrypt import Bcrypt
from functools import wraps
import os
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY')

# MySQL Configuration
app.config['MYSQL_HOST'] = os.getenv('MYSQL_HOST')
app.config['MYSQL_USER'] = os.getenv('MYSQL_USER')
app.config['MYSQL_PASSWORD'] = os.getenv('MYSQL_PASSWORD')
app.config['MYSQL_DB'] = os.getenv('MYSQL_DB')

mysql = MySQL(app)
bcrypt = Bcrypt(app)

# Login required decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Admin required decorator
def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin_id' not in session:
            return redirect(url_for('admin_login'))
        return f(*args, **kwargs)
    return decorated_function

# ==================== HOME ====================
@app.route('/')
def index():
    return render_template('index.html')

# ==================== USER AUTH ====================
def validate_password(password):
    """Validate password strength"""
    if len(password) < 12:
        return False, "Password must be at least 12 characters long"
    if not any(c.isupper() for c in password):
        return False, "Password must contain at least one uppercase letter"
    if not any(c.islower() for c in password):
        return False, "Password must contain at least one lowercase letter"
    if not any(c.isdigit() for c in password):
        return False, "Password must contain at least one number"
    if not any(c in '!@#$%^&*(),.?":{}|<>' for c in password):
        return False, "Password must contain at least one special character"
    return True, "Password is strong"

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form['name']
        email = request.form['email']
        password = request.form['password']
        
        # Validate password
        is_valid, message = validate_password(password)
        if not is_valid:
            flash(message, 'danger')
            return redirect(url_for('register'))
        
        # Hash password
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        
        cur = mysql.connection.cursor()
        
        # Check if email exists
        cur.execute("SELECT * FROM users WHERE email = %s", [email])
        if cur.fetchone():
            flash('Email already registered!', 'danger')
            cur.close()
            return redirect(url_for('register'))
        
        cur.execute("INSERT INTO users (name, email, password, balance) VALUES (%s, %s, %s, 0)", 
                   (name, email, hashed_password))
        mysql.connection.commit()
        cur.close()
        
        flash('Registration successful! Please login.', 'success')
        return redirect(url_for('login'))
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        
        cur = mysql.connection.cursor()
        cur.execute("SELECT * FROM users WHERE email = %s", [email])
        user = cur.fetchone()
        cur.close()
        
        if user and bcrypt.check_password_hash(user[3], password):
            session['user_id'] = user[0]
            session['user_name'] = user[1]
            flash('Login successful!', 'success')
            return redirect(url_for('user_home'))
        else:
            flash('Invalid email or password', 'danger')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

# ==================== USER ROUTES ====================
@app.route('/user/home')
@login_required
def user_home():
    user_id = session['user_id']
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM users WHERE user_id = %s", [user_id])
    user = cur.fetchone()
    cur.close()
    
    return render_template('user/home.html', user=user)

@app.route('/user/dashboard')
@login_required
def user_dashboard():
    user_id = session['user_id']
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM users WHERE user_id = %s", [user_id])
    user = cur.fetchone()
    cur.close()
    
    return render_template('user/dashboard.html', user=user)

@app.route('/user/ipos')
@login_required
def user_ipos():
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM ipo WHERE status = 'OPEN'")
    ipos = cur.fetchall()
    cur.close()
    
    return render_template('user/ipos.html', ipos=ipos)

@app.route('/user/apply', methods=['POST'])
@login_required
def apply_ipo():
    user_id = session['user_id']
    ipo_id = request.form['ipo_id']
    
    try:
        shares = int(request.form['shares'])
    except ValueError:
        flash('Invalid share quantity!', 'danger')
        return redirect(url_for('user_ipos'))
    
    # Basic validation
    if shares <= 0:
        flash('Share quantity must be greater than zero!', 'danger')
        return redirect(url_for('user_ipos'))
    
    if shares > 10000:  # Max shares per application
        flash('Maximum 10,000 shares allowed per application!', 'danger')
        return redirect(url_for('user_ipos'))
    
    cur = mysql.connection.cursor()
    
    try:
        # Start transaction
        cur.execute("START TRANSACTION")
        
        # Lock IPO row
        cur.execute("SELECT * FROM ipo WHERE ipo_id = %s FOR UPDATE", [ipo_id])
        ipo = cur.fetchone()
        
        if not ipo:
            raise Exception("IPO not found")
        
        price = float(ipo[2])
        available_shares = int(ipo[4])
        total_cost = price * shares
        
        # Lock user row
        cur.execute("SELECT balance FROM users WHERE user_id = %s FOR UPDATE", [user_id])
        user = cur.fetchone()
        balance = float(user[0])
        
        # Validations
        if shares > available_shares:
            raise Exception(f"Only {available_shares:,} shares available!")
        
        if total_cost > balance:
            raise Exception(f"Insufficient balance! Required: ₹{total_cost:,.2f}, Available: ₹{balance:,.2f}")
        
        # Deduct balance
        cur.execute("UPDATE users SET balance = balance - %s WHERE user_id = %s", 
                   (total_cost, user_id))
        
        # Reduce available shares
        cur.execute("UPDATE ipo SET available_shares = available_shares - %s WHERE ipo_id = %s", 
                   (shares, ipo_id))
        
        # Insert application
        cur.execute("INSERT INTO ipo_application (user_id, ipo_id, shares_applied, status) VALUES (%s, %s, %s, 'PENDING')", 
                   (user_id, ipo_id, shares))
        
        mysql.connection.commit()
        flash(f'IPO application submitted! {shares:,} shares applied for ₹{total_cost:,.2f}', 'success')
        
    except Exception as e:
        mysql.connection.rollback()
        flash(f'{str(e)}', 'danger')
    
    finally:
        cur.close()
    
    return redirect(url_for('user_ipos'))

# ==================== WALLET RECHARGE ====================
@app.route('/user/wallet', methods=['GET', 'POST'])
@login_required
def wallet():
    user_id = session['user_id']
    
    if request.method == 'POST':
        try:
            amount = float(request.form['amount'])
        except ValueError:
            flash('Invalid amount!', 'danger')
            return redirect(url_for('wallet'))
        
        # Validation
        if amount <= 0:
            flash('Amount must be greater than zero!', 'danger')
            return redirect(url_for('wallet'))
        
        if amount > 1000000:  # Max 10 lakh per transaction
            flash('Maximum recharge amount is ₹10,00,000 per transaction!', 'danger')
            return redirect(url_for('wallet'))
        
        cur = mysql.connection.cursor()
        
        # Check current balance to prevent overflow
        cur.execute("SELECT balance FROM users WHERE user_id = %s", [user_id])
        current_balance = float(cur.fetchone()[0])
        
        if current_balance + amount > 99999999.99:  # Max balance limit
            flash('Maximum wallet balance limit reached!', 'danger')
            cur.close()
            return redirect(url_for('wallet'))
        
        # Add balance
        cur.execute("UPDATE users SET balance = balance + %s WHERE user_id = %s", 
                   (amount, user_id))
        
        # Add transaction record
        cur.execute("INSERT INTO wallet_transactions (user_id, type, amount) VALUES (%s, 'Recharge', %s)", 
                   (user_id, amount))
        
        mysql.connection.commit()
        cur.close()
        
        flash(f'₹{amount:,.2f} added to wallet successfully!', 'success')
        return redirect(url_for('wallet'))
    
    # Get user balance and transactions
    cur = mysql.connection.cursor()
    cur.execute("SELECT balance FROM users WHERE user_id = %s", [user_id])
    balance = cur.fetchone()[0]
    
    cur.execute("""
        SELECT type, amount, transaction_date 
        FROM wallet_transactions 
        WHERE user_id = %s 
        ORDER BY transaction_date DESC 
        LIMIT 20
    """, [user_id])
    transactions = cur.fetchall()
    cur.close()
    
    return render_template('user/wallet.html', balance=balance, transactions=transactions)

# ==================== PORTFOLIO ====================
@app.route('/user/portfolio')
@login_required
def portfolio():
    user_id = session['user_id']
    
    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT i.company_name, p.shares_owned, p.average_price, i.price_per_share,
               (p.shares_owned * i.price_per_share) as current_value,
               (p.shares_owned * i.price_per_share - p.shares_owned * p.average_price) as profit_loss
        FROM portfolio p
        JOIN ipo i ON p.ipo_id = i.ipo_id
        WHERE p.user_id = %s
    """, [user_id])
    holdings = cur.fetchall()
    cur.close()
    
    return render_template('user/portfolio.html', holdings=holdings)

# ==================== MY APPLICATIONS ====================
@app.route('/user/applications')
@login_required
def my_applications():
    user_id = session['user_id']
    
    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT i.company_name, ia.shares_applied, ia.status, ia.applied_at,
               COALESCE(a.shares_allotted, 0) as shares_allotted
        FROM ipo_application ia
        JOIN ipo i ON ia.ipo_id = i.ipo_id
        LEFT JOIN allotment a ON ia.application_id = a.application_id
        WHERE ia.user_id = %s
        ORDER BY ia.applied_at DESC
    """, [user_id])
    applications = cur.fetchall()
    cur.close()
    
    return render_template('user/applications.html', applications=applications)

# ==================== ADMIN AUTH ====================
@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        cur = mysql.connection.cursor()
        cur.execute("SELECT * FROM admin WHERE username = %s", [username])
        admin = cur.fetchone()
        cur.close()
        
        if admin and bcrypt.check_password_hash(admin[2], password):
            session['admin_id'] = admin[0]
            session['admin_name'] = admin[1]
            flash('Admin login successful!', 'success')
            return redirect(url_for('admin_dashboard'))
        else:
            flash('Invalid username or password', 'danger')
    
    return render_template('admin/login.html')

# ==================== ADMIN ROUTES ====================
@app.route('/admin/dashboard')
@admin_required
def admin_dashboard():
    cur = mysql.connection.cursor()
    
    # Statistics
    cur.execute("SELECT COUNT(*) FROM ipo_application")
    total_apps = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(*) FROM ipo_application WHERE status = 'APPROVED'")
    approved = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(*) FROM ipo_application WHERE status = 'PENDING'")
    pending = cur.fetchone()[0]
    
    # Applications
    cur.execute("""
        SELECT ia.application_id, u.name, i.company_name, 
               ia.shares_applied, ia.status
        FROM ipo_application ia
        JOIN users u ON ia.user_id = u.user_id
        JOIN ipo i ON ia.ipo_id = i.ipo_id
        ORDER BY ia.application_id DESC
    """)
    applications = cur.fetchall()
    
    cur.close()
    
    return render_template('admin/dashboard.html', 
                         total_apps=total_apps, 
                         approved=approved, 
                         pending=pending,
                         applications=applications)

@app.route('/admin/add_ipo', methods=['GET', 'POST'])
@admin_required
def add_ipo():
    if request.method == 'POST':
        company = request.form['company_name']
        price = request.form['price_per_share']
        total = request.form['total_shares']
        available = request.form['available_shares']
        open_date = request.form['open_date']
        close_date = request.form['close_date']
        
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO ipo (company_name, price_per_share, total_shares, 
                           available_shares, open_date, close_date, status)
            VALUES (%s, %s, %s, %s, %s, %s, 'OPEN')
        """, (company, price, total, available, open_date, close_date))
        mysql.connection.commit()
        cur.close()
        
        flash('IPO added successfully!', 'success')
        return redirect(url_for('add_ipo'))
    
    return render_template('admin/add_ipo.html')

@app.route('/admin/approve', methods=['POST'])
@admin_required
def approve_application():
    application_id = int(request.form['application_id'])
    
    try:
        shares = int(request.form['shares'])
    except ValueError:
        flash('Invalid share quantity!', 'danger')
        return redirect(url_for('admin_dashboard'))
    
    if shares <= 0:
        flash('Share quantity must be greater than zero!', 'danger')
        return redirect(url_for('admin_dashboard'))
    
    cur = mysql.connection.cursor()
    
    try:
        # Get application
        cur.execute("SELECT * FROM ipo_application WHERE application_id = %s", [application_id])
        app = cur.fetchone()
        
        if not app:
            flash('Application not found!', 'danger')
            return redirect(url_for('admin_dashboard'))
        
        applied_shares = int(app[3])
        ipo_id = int(app[2])
        user_id = int(app[1])
        
        # Get IPO details
        cur.execute("SELECT available_shares, price_per_share FROM ipo WHERE ipo_id = %s", [ipo_id])
        ipo = cur.fetchone()
        available = int(ipo[0])
        price = float(ipo[1])
        
        # Validations
        if shares > applied_shares:
            flash(f'Cannot approve more than applied shares! Applied: {applied_shares:,}', 'danger')
            return redirect(url_for('admin_dashboard'))
        
        if shares > available:
            flash(f'Not enough IPO shares available! Available: {available:,}', 'danger')
            return redirect(url_for('admin_dashboard'))
        
        total_cost = shares * price
        
        # Check user balance
        cur.execute("SELECT balance FROM users WHERE user_id = %s", [user_id])
        user = cur.fetchone()
        
        if float(user[0]) < total_cost:
            flash(f'User does not have enough balance! Required: ₹{total_cost:,.2f}', 'danger')
            return redirect(url_for('admin_dashboard'))
        
        # Start transaction
        cur.execute("START TRANSACTION")
        
        # Insert allotment
        cur.execute("INSERT INTO allotment (application_id, shares_allotted) VALUES (%s, %s)", 
                   (application_id, shares))
        
        # Update application status
        cur.execute("UPDATE ipo_application SET status = 'APPROVED' WHERE application_id = %s", 
                   [application_id])
        
        # Reduce IPO shares
        cur.execute("UPDATE ipo SET available_shares = available_shares - %s WHERE ipo_id = %s", 
                   (shares, ipo_id))
        
        # Deduct balance
        cur.execute("UPDATE users SET balance = balance - %s WHERE user_id = %s", 
                   (total_cost, user_id))
        
        # Add wallet transaction
        cur.execute("INSERT INTO wallet_transactions (user_id, type, amount) VALUES (%s, 'IPO Purchase', %s)", 
                   (user_id, total_cost))
        
        # Update portfolio
        cur.execute("SELECT * FROM portfolio WHERE user_id = %s AND ipo_id = %s", (user_id, ipo_id))
        portfolio = cur.fetchone()
        
        if portfolio:
            cur.execute("UPDATE portfolio SET shares_owned = shares_owned + %s WHERE user_id = %s AND ipo_id = %s", 
                       (shares, user_id, ipo_id))
        else:
            cur.execute("INSERT INTO portfolio (user_id, ipo_id, shares_owned, average_price) VALUES (%s, %s, %s, %s)", 
                       (user_id, ipo_id, shares, price))
        
        mysql.connection.commit()
        flash(f'Application approved! {shares:,} shares allotted for ₹{total_cost:,.2f}', 'success')
        
    except Exception as e:
        mysql.connection.rollback()
        flash(f'Approval failed: {str(e)}', 'danger')
    
    finally:
        cur.close()
    
    return redirect(url_for('admin_dashboard'))

if __name__ == '__main__':
    app.run(debug=True)
