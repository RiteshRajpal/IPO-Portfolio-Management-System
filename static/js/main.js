// Auto-dismiss alerts
document.addEventListener('DOMContentLoaded', function() {
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach(alert => {
        setTimeout(() => {
            const bsAlert = new bootstrap.Alert(alert);
            bsAlert.close();
        }, 5000);
    });

    // Password visibility toggle
    const passwordToggles = document.querySelectorAll('.password-toggle');
    passwordToggles.forEach(toggle => {
        toggle.addEventListener('click', function() {
            const input = this.previousElementSibling;
            const icon = this.querySelector('i');
            
            if (input.type === 'password') {
                input.type = 'text';
                icon.classList.remove('fa-eye');
                icon.classList.add('fa-eye-slash');
            } else {
                input.type = 'password';
                icon.classList.remove('fa-eye-slash');
                icon.classList.add('fa-eye');
            }
        });
    });

    // Password strength checker
    const passwordInputs = document.querySelectorAll('input[name="password"]');
    passwordInputs.forEach(input => {
        // Only add validation on register page
        if (window.location.pathname.includes('register')) {
            const strengthBar = document.createElement('div');
            strengthBar.className = 'password-strength';
            input.parentElement.appendChild(strengthBar);

            const requirements = document.createElement('ul');
            requirements.className = 'password-requirements';
            requirements.innerHTML = `
                <li id="req-length">At least 12 characters</li>
                <li id="req-upper">One uppercase letter</li>
                <li id="req-lower">One lowercase letter</li>
                <li id="req-number">One number</li>
                <li id="req-special">One special character</li>
            `;
            input.parentElement.appendChild(requirements);

            input.addEventListener('input', function() {
                const value = this.value;
                let strength = 0;

                // Check length
                const hasLength = value.length >= 12;
                document.getElementById('req-length').className = hasLength ? 'valid' : 'invalid';
                if (hasLength) strength++;

                // Check uppercase
                const hasUpper = /[A-Z]/.test(value);
                document.getElementById('req-upper').className = hasUpper ? 'valid' : 'invalid';
                if (hasUpper) strength++;

                // Check lowercase
                const hasLower = /[a-z]/.test(value);
                document.getElementById('req-lower').className = hasLower ? 'valid' : 'invalid';
                if (hasLower) strength++;

                // Check number
                const hasNumber = /[0-9]/.test(value);
                document.getElementById('req-number').className = hasNumber ? 'valid' : 'invalid';
                if (hasNumber) strength++;

                // Check special character
                const hasSpecial = /[!@#$%^&*(),.?":{}|<>]/.test(value);
                document.getElementById('req-special').className = hasSpecial ? 'valid' : 'invalid';
                if (hasSpecial) strength++;

                // Update strength bar
                strengthBar.className = 'password-strength';
                if (strength <= 2) {
                    strengthBar.classList.add('weak');
                } else if (strength <= 4) {
                    strengthBar.classList.add('medium');
                } else {
                    strengthBar.classList.add('strong');
                }

                // Validate form
                const isValid = hasLength && hasUpper && hasLower && hasNumber && hasSpecial;
                this.setCustomValidity(isValid ? '' : 'Password does not meet requirements');
            });
        }
    });

    // Test login buttons
    const testLoginButtons = document.querySelectorAll('.test-login-btn');
    testLoginButtons.forEach(button => {
        button.addEventListener('click', function() {
            const email = this.dataset.email;
            const username = this.dataset.username;
            const password = this.dataset.password;

            if (email) {
                document.querySelector('input[name="email"]').value = email;
            }
            if (username) {
                document.querySelector('input[name="username"]').value = username;
            }
            if (password) {
                document.querySelector('input[name="password"]').value = password;
            }
        });
    });

    // Form validation
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            if (!form.checkValidity()) {
                e.preventDefault();
                e.stopPropagation();
            }
            form.classList.add('was-validated');
        });
    });

    // Number input validation
    const numberInputs = document.querySelectorAll('input[type="number"]');
    numberInputs.forEach(input => {
        input.addEventListener('input', function() {
            if (this.value < 0) this.value = 0;
        });
    });

    // Confirm before approve
    const approveButtons = document.querySelectorAll('form[action*="approve"] button[type="submit"]');
    approveButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            const form = this.closest('form');
            const shares = form.querySelector('input[name="shares"]').value;
            if (!confirm(`Approve ${shares} shares?`)) {
                e.preventDefault();
            }
        });
    });

    // Animate cards on scroll
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-fade-in');
            }
        });
    }, observerOptions);

    document.querySelectorAll('.card-custom, .stat-card, .ipo-card').forEach(card => {
        observer.observe(card);
    });
});
