import os
from flask import Flask, request, make_response
from apps.models import db
from apps.migrations import run_additive_migrations
from flask_login import LoginManager
from urllib.parse import quote_plus

login_manager = LoginManager()



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
    sql_server = os.environ.get('DB_SERVER', r"vinothkumar\SQLEXPRESS").strip()
    sql_database = os.environ.get('DB_DATABASE', "exam").strip()
    sql_driver = os.environ.get('DB_DRIVER', "ODBC Driver 17 for SQL Server").strip()

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
        if request.method == 'OPTIONS':
            resp = make_response('', 204)
            origin = request.headers.get('Origin')
            if origin:
                resp.headers['Access-Control-Allow-Origin'] = origin
                resp.headers['Access-Control-Allow-Credentials'] = 'true'
                resp.headers['Vary'] = 'Origin'
            else:
                resp.headers['Access-Control-Allow-Origin'] = '*'

            req_headers = request.headers.get('Access-Control-Request-Headers')
            if req_headers:
                resp.headers['Access-Control-Allow-Headers'] = req_headers
            else:
                resp.headers['Access-Control-Allow-Headers'] = (
                    'Content-Type, Authorization, Accept, X-Requested-With, Origin, Access-Control-Request-Method, Access-Control-Request-Headers'
                )

            resp.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
            resp.headers['Access-Control-Max-Age'] = '86400'
            resp.headers['Access-Control-Expose-Headers'] = 'Content-Type, Authorization'
            resp.headers['Access-Control-Allow-Private-Network'] = 'true'
            return resp

    @app.after_request
    def add_api_headers(response):
        origin = request.headers.get('Origin')
        if origin:
            response.headers['Access-Control-Allow-Origin'] = origin
            response.headers['Access-Control-Allow-Credentials'] = 'true'
            response.headers['Vary'] = 'Origin'
        else:
            response.headers.setdefault('Access-Control-Allow-Origin', '*')

        req_headers = request.headers.get('Access-Control-Request-Headers')
        if req_headers:
            response.headers['Access-Control-Allow-Headers'] = req_headers
        else:
            response.headers.setdefault(
                'Access-Control-Allow-Headers',
                'Content-Type, Authorization, Accept, X-Requested-With, Origin, Access-Control-Request-Method, Access-Control-Request-Headers'
            )
        response.headers['Access-Control-Allow-Methods'] = (
            'GET, POST, PUT, PATCH, DELETE, OPTIONS'
        )
        response.headers['Access-Control-Max-Age'] = '86400'
        response.headers['Access-Control-Expose-Headers'] = 'Content-Type, Authorization'
        response.headers['Access-Control-Allow-Private-Network'] = 'true'
        return response

    login_manager.init_app(app)

    @login_manager.user_loader
    def load_user(user_id):
        from apps.models import User
        try:
            return User.query.get(int(user_id))
        except Exception:
            return None

    # ------------------------------------------------------------------
    # Safe additive database migrations:
    # Automatically synchronizes database schema with current SQLAlchemy models.
    # Runs against the actual configured db.engine (SQL Server, SQLite, etc.)
    # BEFORE any application query, blueprint, or API request can execute.
    # ------------------------------------------------------------------
    with app.app_context():
        run_additive_migrations(app)


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
    from apps.exams.teams import teams_bp
    from apps.exams.audit_logs import audit_logs_bp

    # --- Employees module ---
    from apps.employees.routes import employees_bp

    app.register_blueprint(exams_dashboard_bp)
    app.register_blueprint(exam_types_bp)
    app.register_blueprint(branch_exams_bp)
    app.register_blueprint(sessions_bp)
    app.register_blueprint(candidates_bp)
    app.register_blueprint(teams_bp)
    app.register_blueprint(audit_logs_bp)
    app.register_blueprint(employees_bp)

    # Mobile/API layer, modelled after the WorkLog API architecture.
    from api import api_bp
    app.register_blueprint(api_bp)

    with app.app_context():
        db.create_all()
        seed_expense_categories()
        backfill_exam_attempts()

    return app