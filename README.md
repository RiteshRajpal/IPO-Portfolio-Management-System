# IPO Management System

Modern IPO management platform built with Python Flask, MySQL, and responsive HTML/CSS/JS.

## Features

### User Features
- Secure registration with strong password requirements (12+ chars, uppercase, lowercase, number, special char)
- Login with password visibility toggle
- Wallet management with recharge functionality
- Browse and apply for IPOs
- View portfolio with profit/loss tracking
- Transaction history
- Application status tracking

### Admin Features
- Secure admin portal
- View all IPO applications
- Approve/reject applications with share allocation
- Add new IPOs
- Real-time statistics dashboard

### Security
- Bcrypt password hashing
- ACID transaction support for financial operations
- SQL injection prevention with parameterized queries
- Session management
- Input validation

### UI/UX
- Clean, modern interface
- Fully responsive design
- Password strength indicator
- Show/hide password toggle
- Quick test login buttons for development
- Real-time form validation
- Smooth animations

## Quick Setup

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure Environment
Update `.env` file with your MySQL password:
```
MYSQL_PASSWORD=your_mysql_password_here
```

### 3. Initialize Database
```bash
python init_db.py
```

This will:
- Create database and tables
- Add indexes for performance
- Insert sample data
- Create test accounts

### 4. Run Application
```bash
python app.py
```

Open browser: http://127.0.0.1:5000

## Test Credentials

### Admin Login
- URL: http://127.0.0.1:5000/admin/login
- Username: `admin`
- Password: `Admin@123456`

### User Accounts
**Test User:**
- Email: `test@example.com`
- Password: `Test@123456`
- Balance: ₹100,000

**Demo User:**
- Email: `demo@example.com`
- Password: `Test@123456`
- Balance: ₹50,000 

*Quick login buttons available on login pages for easy testing*

## Password Requirements

New passwords must have:
- Minimum 12 characters
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one number (0-9)
- At least one special character (!@#$%^&*(),.?":{}|<>)

## Tech Stack

**Backend:**
- Python 3.x
- Flask 3.0
- Flask-MySQLdb
- Flask-Bcrypt
- python-dotenv

**Frontend:**
- HTML5
- CSS3 (Custom, no frameworks)
- JavaScript (Vanilla)
- Bootstrap 5 (Grid & Components)
- Font Awesome Icons

**Database:**
- MySQL 8.0+

## Project Structure
```
.
├── app.py                 # Main Flask application
├── init_db.py            # Database initialization script
├── requirements.txt      # Python dependencies
├── .env                  # Environment configuration
├── templates/            # HTML templates
│   ├── base.html
│   ├── index.html
│   ├── login.html
│   ├── register.html
│   ├── admin/
│   │   ├── login.html
│   │   ├── dashboard.html
│   │   └── add_ipo.html
│   └── user/
│       ├── home.html
│       ├── dashboard.html
│       ├── ipos.html
│       ├── wallet.html
│       ├── portfolio.html
│       └── applications.html
└── static/
    ├── css/
    │   └── style.css
    └── js/
        └── main.js
```

## Database Schema

- **users** - User accounts with wallet balance
- **admin** - Admin accounts
- **ipo** - IPO listings
- **ipo_application** - User IPO applications
- **allotment** - Share allotments
- **portfolio** - User holdings
- **wallet_transactions** - Transaction history

## Development

To reset database:
```bash
python init_db.py
```

To update existing passwords to hashed format:
```bash
python update_passwords.py
```

## Production Deployment

For production:
1. Change `SECRET_KEY` in `.env`
2. Set `debug=False` in `app.py`
3. Use production WSGI server (gunicorn/uwsgi)
4. Enable HTTPS
5. Use environment variables for sensitive data
6. Set up proper MySQL user with limited permissions

## License

MIT License
