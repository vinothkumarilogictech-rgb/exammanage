import os
import sqlite3
from flask import Flask, request
from apps.models import db
from flask_login import LoginManager
from urllib.parse import quote_plus

login_manager = LoginManager()


def ensure_bank_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        return

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.execute("PRAGMA table_info(bank)")
        columns = {row[1] for row in cursor.fetchall()}

        migrations = {
            "address": "VARCHAR(300)",
            "date": "TEXT",
            "customer_name": "VARCHAR(150)",
            "invoice_number": "VARCHAR(100)",
            "amount": "FLOAT",
            "payment_mode": "VARCHAR(50)",
            "payment_reference": "VARCHAR(150)",
            "transaction_type": "VARCHAR(20)",
        }

        for column_name, column_type in migrations.items():
            if column_name not in columns:
                conn.execute(f"ALTER TABLE bank ADD COLUMN {column_name} {column_type}")
    finally:
        conn.commit()
        conn.close()


def ensure_invoice_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        return

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.execute("PRAGMA table_info(invoice)")
        columns = {row[1] for row in cursor.fetchall()}

        if "invoice_type" not in columns:
            conn.execute("ALTER TABLE invoice ADD COLUMN invoice_type VARCHAR(50) DEFAULT 'not_paid'")
    finally:
        conn.commit()
        conn.close()


def ensure_vendor_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        return

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.execute("PRAGMA table_info(vendor)")
        columns = {row[1] for row in cursor.fetchall()}

        if "address" not in columns:
            conn.execute("ALTER TABLE vendor ADD COLUMN address VARCHAR(300)")
    finally:
        conn.commit()
        conn.close()


def ensure_customer_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        return

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.execute("PRAGMA table_info(customer)")
        columns = {row[1] for row in cursor.fetchall()}

        migrations = {
            "address": "VARCHAR(300)",
            "credit_limit": "FLOAT DEFAULT 0.0",
            "outstanding_amount": "FLOAT DEFAULT 0.0",
        }

        for column_name, column_type in migrations.items():
            if column_name not in columns:
                conn.execute(f"ALTER TABLE customer ADD COLUMN {column_name} {column_type}")
    finally:
        conn.commit()
        conn.close()


def ensure_expense_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        return

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.execute("PRAGMA table_info(expense)")
        columns = {row[1] for row in cursor.fetchall()}

        migrations = {
            "branch_id": "INTEGER",
            "category_id": "INTEGER",
            "payment_mode": "VARCHAR(50)",
            "receipt_file": "VARCHAR(400)",
            "status": "VARCHAR(20) DEFAULT 'Active'",
            "created_at": "DATETIME",
            "updated_at": "DATETIME",
        }

        for column_name, column_type in migrations.items():
            if column_name not in columns:
                conn.execute(f"ALTER TABLE expense ADD COLUMN {column_name} {column_type}")
    finally:
        conn.commit()
        conn.close()


def ensure_candidate_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        return

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.execute("PRAGMA table_info(candidate)")
        columns = {row[1] for row in cursor.fetchall()}

        migrations = {
            "register_number": "VARCHAR(100)",
            "test_type": "VARCHAR(100)",
            "exam_date": "VARCHAR(20)",
            "status": "VARCHAR(30) DEFAULT 'Registered'",
            "original_exam_date": "VARCHAR(20)",
            "rescheduled_date": "VARCHAR(20)",
            "reason_note": "TEXT",
            "branch_id": "INTEGER",
            "exam_type_id": "INTEGER",
            "team_id": "INTEGER",
        }

        for column_name, column_type in migrations.items():
            if column_name not in columns:
                conn.execute(f"ALTER TABLE candidate ADD COLUMN {column_name} {column_type}")
    finally:
        conn.commit()
        conn.close()



def ensure_employee_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)
    if not os.path.exists(db_path):
        return
    conn = sqlite3.connect(db_path)
    try:
        columns = {row[1] for row in conn.execute("PRAGMA table_info(employee)").fetchall()}
        if 'basic_salary' not in columns:
            conn.execute("ALTER TABLE employee ADD COLUMN basic_salary FLOAT DEFAULT 0.0")
        ecols = {row[1] for row in conn.execute("PRAGMA table_info(expense)").fetchall()}
        if 'employee_id' not in ecols:
            conn.execute("ALTER TABLE expense ADD COLUMN employee_id INTEGER")
        conn.commit()
    finally:
        conn.close()

def ensure_exam_attempt_columns(app):
    db_path = os.path.join(app.root_path, '..', 'flask_erp.db')
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        return

    conn = sqlite3.connect(db_path)
    try:
        cursor = conn.execute("PRAGMA table_info(exam_attempt)")
        columns = {row[1] for row in cursor.fetchall()}

        migrations = {
            "session_id": "INTEGER",
        }

        for column_name, column_type in migrations.items():
            if column_name not in columns:
                conn.execute(f"ALTER TABLE exam_attempt ADD COLUMN {column_name} {column_type}")
    finally:
        conn.commit()
        conn.close()


def backfill_exam_attempts():
    """One-time migration: give every pre-existing Candidate row (which used
    to carry its own single branch/exam/date/status directly) an equivalent
    Attempt 1 record in the new exam_attempt table.

    Safe to call on every startup - it only ever looks at candidates that
    have zero attempts yet, so it never touches or duplicates a candidate
    that already has attempt history. No existing candidate rows are
    modified or deleted.
    """
    from apps.models import Candidate, ExamAttempt
    candidates_needing_backfill = Candidate.query.filter(
        Candidate.exam_date.isnot(None), Candidate.exam_date != ''
    ).all()
    for c in candidates_needing_backfill:
        if ExamAttempt.query.filter_by(candidate_id=c.id).first():
            continue  # already has attempt history - never overwrite
        if not c.branch_id or not c.exam_type_id:
            continue  # not enough data to build a valid attempt; leave as-is

        legacy_status = c.status or 'Registered'
        status_map = {
            'Registered': 'Scheduled', 'Scheduled': 'Scheduled',
            'Completed': 'Completed', 'Cancelled': 'Cancelled',
            'Absent': 'No Show', 'Rescheduled': 'Scheduled',
        }
        attempt = ExamAttempt(
            candidate_id=c.id,
            exam_type_id=c.exam_type_id,
            branch_id=c.branch_id,
            attempt_number=1,
            original_scheduled_date=c.original_exam_date or c.exam_date,
            scheduled_date=c.exam_date,
            actual_exam_date=c.exam_date if legacy_status == 'Completed' else None,
            status=status_map.get(legacy_status, 'Scheduled'),
            result='Pending',
            cancellation_reason=c.reason_note if legacy_status == 'Cancelled' else None,
            reschedule_reason=c.reason_note if legacy_status == 'Rescheduled' else None,
        )
        db.session.add(attempt)
    if candidates_needing_backfill:
        db.session.commit()


def seed_expense_categories():
    """Populate the default BRD expense categories once, if the table is empty.
    Safe to call every startup - it never touches existing rows."""
    from apps.models import ExpenseCategory
    if ExpenseCategory.query.first():
        return
    defaults = ['Salaries', 'Rent', 'Utilities', 'Maintenance', 'Marketing', 'Exam Material', 'Exam Voucher Purchase', 'Other']
    for name in defaults:
        db.session.add(ExpenseCategory(name=name, status='Active'))
    db.session.commit()


def create_app():
    # Dynamically find the absolute path of the root 'officemanagement' directory
    apps_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(apps_dir)

    app = Flask(__name__, 
                template_folder=os.path.join(root_dir, 'templates'), 
                static_folder=os.path.join(root_dir, 'static'))
    
    app.config['SECRET_KEY'] = 'dev_secret_key_for_boss_erp'
    sql_server = os.environ.get('DB_SERVER', r"vinothkumar\SQLEXPRESS")
    sql_database = os.environ.get('DB_DATABASE', "exam")
    sql_driver = os.environ.get('DB_DRIVER', "ODBC Driver 17 for SQL Server")

    odbc_connection_string = (
        f"DRIVER={{{sql_driver}}};"
        f"SERVER={sql_server};"
        f"DATABASE={sql_database};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )

    app.config['SQLALCHEMY_DATABASE_URI'] = (
    "mssql+pyodbc:///?odbc_connect="
    + quote_plus(odbc_connection_string)
)
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'office-management-change-this-secret')
    app.config['JWT_ACCESS_TOKEN_EXPIRES'] = 1800
    app.config['JWT_REFRESH_TOKEN_EXPIRES'] = 604800

    db.init_app(app)

    # ------------------------------------------------------------------
    # CORS / browser preflight support for the Flutter Web client.
    # Dio sends JSON requests with an Authorization header, so browsers
    # perform an OPTIONS preflight before calls such as GET /exams/teams/.
    # Keep this handling outside the authentication decorators: OPTIONS
    # is a browser capability check, not an authenticated API operation.
    # ------------------------------------------------------------------
    @app.before_request
    def handle_api_preflight():
        if request.method == 'OPTIONS' and request.path.startswith('/api/'):
            return ('', 204)

    @app.after_request
    def add_api_headers(response):
        origin = request.headers.get('Origin')
        if origin:
            response.headers['Access-Control-Allow-Origin'] = origin
            response.headers['Vary'] = 'Origin'
        else:
            response.headers.setdefault('Access-Control-Allow-Origin', '*')
        response.headers['Access-Control-Allow-Headers'] = (
            'Content-Type, Authorization, Accept, X-Requested-With'
        )
        response.headers['Access-Control-Allow-Methods'] = (
            'GET, POST, PUT, PATCH, DELETE, OPTIONS'
        )
        response.headers['Access-Control-Max-Age'] = '86400'
        response.headers['Access-Control-Expose-Headers'] = 'Content-Type'
        # Chrome may send this for requests from a local web app to a
        # different local/LAN address. It is harmless for normal CORS.
        response.headers['Access-Control-Allow-Private-Network'] = 'true'
        return response

    login_manager.init_app(app)

    ensure_bank_columns(app)
    ensure_invoice_columns(app)
    ensure_vendor_columns(app)
    ensure_customer_columns(app)
    ensure_expense_columns(app)
    ensure_employee_columns(app)
    ensure_candidate_columns(app)
    ensure_exam_attempt_columns(app)

    # SQL Server deployments need explicit additive migrations because create_all
    # does not alter existing tables.
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            insp = inspect(db.engine)
            if 'employee' in insp.get_table_names():
                cols = {c['name'] for c in insp.get_columns('employee')}
                if 'basic_salary' not in cols:
                    db.session.execute(text("ALTER TABLE employee ADD basic_salary FLOAT NOT NULL CONSTRAINT DF_employee_basic_salary DEFAULT 0"))
            if 'expense' in insp.get_table_names():
                cols = {c['name'] for c in insp.get_columns('expense')}
                if 'employee_id' not in cols:
                    db.session.execute(text("ALTER TABLE expense ADD employee_id INT NULL"))
            db.session.commit()
        except Exception:
            db.session.rollback()

    # Register only the four enabled workspace modules.
    from apps.branches.routes import branches_bp
    from apps.expenses.routes import expenses_bp
    from apps.vouchers.routes import vouchers_bp

    app.register_blueprint(branches_bp)
    app.register_blueprint(expenses_bp)
    app.register_blueprint(vouchers_bp)

    # --- Exam Management module ---
    from apps.exams.dashboard import exams_dashboard_bp
    from apps.exams.exam_types import exam_types_bp
    from apps.exams.branch_exams import branch_exams_bp
    from apps.exams.sessions import sessions_bp
    from apps.exams.candidates import candidates_bp
    from apps.exams.audit_logs import audit_logs_bp

    app.register_blueprint(exams_dashboard_bp)
    app.register_blueprint(exam_types_bp)
    app.register_blueprint(branch_exams_bp)
    app.register_blueprint(sessions_bp)
    app.register_blueprint(candidates_bp)
    app.register_blueprint(audit_logs_bp)

    # Mobile/API layer, modelled after the WorkLog API architecture.
    from api import api_bp
    app.register_blueprint(api_bp)

    with app.app_context():
        db.create_all()
        seed_expense_categories()
        backfill_exam_attempts()

    return app