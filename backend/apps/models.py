from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from sqlalchemy.orm import synonym
from datetime import datetime

db = SQLAlchemy()

# --- MASTERS & AUTH ---
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(150), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)


class EmployeeCredential(db.Model):
    __tablename__ = 'employee_credential'
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employee.id'), unique=True, nullable=False)
    username = db.Column(db.String(150), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    employee = db.relationship('Employee', backref=db.backref('credential', uselist=False))
class Bank(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    account_name = db.Column(db.String(100), nullable=True)
    account_number = db.Column(db.String(50), unique=True, nullable=True)
    opening_balance = db.Column(db.Float, default=0.0)
    current_balance = db.Column(db.Float, default=0.0)
    date = db.Column(db.Date, nullable=True)
    customer_name = db.Column(db.String(150), nullable=True)
    address = db.Column(db.String(300), nullable=True)
    invoice_number = db.Column(db.String(100), nullable=True)
    amount = db.Column(db.Float, default=0.0)
    payment_mode = db.Column(db.String(50), nullable=True)
    payment_reference = db.Column(db.String(150), nullable=True)
    transaction_type = db.Column(db.String(20), default='credit')  # 'credit'


class Customer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    contact = db.Column(db.String(50))
    address = db.Column(db.String(300), nullable=True)
    credit_limit = db.Column(db.Float, default=0.0)
    outstanding_amount = db.Column(db.Float, default=0.0)
    quotations = db.relationship('Quotation', backref='customer', lazy=True)
    invoices = db.relationship('Invoice', backref='customer', lazy=True)

class Vendor(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    contact = db.Column(db.String(50))
    address = db.Column(db.String(300), nullable=True)
    outstanding_amount = db.Column(db.Float, default=0.0)
    purchases = db.relationship('Purchase', backref='vendor', lazy=True)

class Product(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    description = db.Column(db.Text)
    base_price = db.Column(db.Float, default=0.0)
    inventory_items = db.relationship('InventoryItem', backref='product_catalog', lazy=True)

class InventoryItem(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    serial_number = db.Column(db.String(100), unique=True, nullable=False)
    status = db.Column(db.String(50), default='Available')  # Available, Sold, Returned, Replaced
    purchase_id = db.Column(db.Integer, db.ForeignKey('purchase.id'), nullable=True)

# --- TRANSACTIONS ---
class Quotation(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(db.Integer, db.ForeignKey('customer.id'), nullable=False)
    quote_type = db.Column(db.String(50), nullable=False)  # Single, Bundled, FOC
    total_amount = db.Column(db.Float, default=0.0)
    date_created = db.Column(db.DateTime, default=datetime.utcnow)
    status = db.Column(db.String(50), default='Pending')
    items = db.relationship('QuotationItem', backref='quotation', lazy=True)
    invoice = db.relationship('Invoice', backref='quotation', uselist=False)

class QuotationItem(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    quotation_id = db.Column(db.Integer, db.ForeignKey('quotation.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    quantity = db.Column(db.Integer, default=1)
    unit_price = db.Column(db.Float, default=0.0)
    product = db.relationship('Product')

class Invoice(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    quotation_id = db.Column(db.Integer, db.ForeignKey('quotation.id'), nullable=False)
    customer_id = db.Column(db.Integer, db.ForeignKey('customer.id'), nullable=False)
    total_amount = db.Column(db.Float, nullable=False)
    invoice_type = db.Column(db.String(50), default='not_paid', nullable=False)
    date_issued = db.Column(db.DateTime, default=datetime.utcnow)
    is_collected = db.Column(db.Boolean, default=False)

class InvoicePayment(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    invoice_id = db.Column(db.Integer, db.ForeignKey('invoice.id'), nullable=False)
    payment_date = db.Column(db.Date, nullable=True)
    mode = db.Column(db.String(50), default='Cash')
    bank = db.Column(db.String(100), nullable=True)
    cheque_no = db.Column(db.String(100), nullable=True)
    amount = db.Column(db.Float, default=0.0)
    invoice = db.relationship('Invoice', backref='payments', lazy=True)

class Purchase(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    vendor_id = db.Column(db.Integer, db.ForeignKey('vendor.id'), nullable=False)
    currency_code = db.Column(db.String(3), default='SGD')  # USD, SGD
    exchange_rate = db.Column(db.Float, default=1.0)
    foreign_amount = db.Column(db.Float, default=0.0)
    local_amount = db.Column(db.Float, default=0.0)
    date_purchased = db.Column(db.DateTime, default=datetime.utcnow)
    stock_items = db.relationship('InventoryItem', backref='purchase_record', lazy=True)

class ReturnReplacement(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    invoice_id = db.Column(db.Integer, db.ForeignKey('invoice.id'), nullable=False)
    old_inventory_item_id = db.Column(db.Integer, db.ForeignKey('inventory_item.id'), nullable=False)
    new_inventory_item_id = db.Column(db.Integer, db.ForeignKey('inventory_item.id'), nullable=True)
    type = db.Column(db.String(50), default='Replacement')
    date_processed = db.Column(db.DateTime, default=datetime.utcnow)
    invoice = db.relationship('Invoice')
    old_inventory_item = db.relationship('InventoryItem', foreign_keys=[old_inventory_item_id])
    new_inventory_item = db.relationship('InventoryItem', foreign_keys=[new_inventory_item_id])

class Expense(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    category = db.Column(db.String(50), nullable=False)  # legacy free-text category (kept for backward compatibility)
    amount = db.Column(db.Float, nullable=False)
    description = db.Column(db.Text)
    date_incurred = db.Column(db.DateTime, default=datetime.utcnow)

    # --- Expense Management module additions ---
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=True)
    category_id = db.Column(db.Integer, db.ForeignKey('expense_category.id'), nullable=True)
    payment_mode = db.Column(db.String(50), nullable=True)  # Cash, Bank Transfer, UPI, Card, Other
    receipt_file = db.Column(db.String(400), nullable=True)
    status = db.Column(db.String(20), default='Active')  # Active / Cancelled
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    branch = db.relationship('Branch', backref='expenses')
    expense_category = db.relationship('ExpenseCategory', backref='expenses')
    employee_id = db.Column(db.Integer, db.ForeignKey('employee.id'), nullable=True, index=True)
    employee = db.relationship('Employee', backref='salary_expenses', foreign_keys=[employee_id])

    # `note` is the BRD's name for this field; it's the same column as the
    # pre-existing `description` so old records/routes keep working.
    note = synonym('description')

class Setting(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    company_name = db.Column(db.String(150), default='Office Management')
    currency_code = db.Column(db.String(10), default='SGD')
    gst_percent = db.Column(db.Float, default=9.0)

# --- BRANCH MANAGEMENT ---
class Branch(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    branch_name = db.Column(db.String(150), unique=True, nullable=False)
    address = db.Column(db.String(300), nullable=True)
    contact_info = db.Column(db.String(150), nullable=True)
    region = db.Column(db.String(100), nullable=True)
    status = db.Column(db.String(20), default='Active')  # Active, Inactive
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Compatibility aliases: the Exam Management module (built independently)
    # refers to branches as `name` / `location`. These synonyms let that code
    # work unmodified against the single canonical Branch model/table instead
    # of introducing a second Branch table.
    name = synonym('branch_name')
    location = synonym('address')

# --- EMPLOYEE MANAGEMENT ---
class Employee(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.String(50), unique=True, nullable=False)
    basic_salary = db.Column(db.Float, default=0.0, nullable=False)
    full_name = db.Column(db.String(150), nullable=False)
    designation = db.Column(db.String(100), nullable=False)
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=False)
    contact_number = db.Column(db.String(50), nullable=True)
    email = db.Column(db.String(150), nullable=True)
    joining_date = db.Column(db.Date, nullable=False)
    address = db.Column(db.String(300), nullable=True)
    status = db.Column(db.String(20), default='Active')  # Active, Inactive
    exit_date = db.Column(db.Date, nullable=True)
    exit_reason = db.Column(db.String(300), nullable=True)
    exit_remarks = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    branch = db.relationship('Branch', backref='employees')
    transfers = db.relationship('EmployeeTransferHistory', backref='employee', lazy=True,
                                 foreign_keys='EmployeeTransferHistory.employee_id')
    attendance_records = db.relationship('EmployeeAttendance', backref='employee', lazy=True)
    payroll_records = db.relationship('EmployeePayroll', backref='employee', lazy=True)
    documents = db.relationship('EmployeeDocument', backref='employee', lazy=True)


class EmployeeTransferHistory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employee.id'), nullable=False)
    old_branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=True)
    new_branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=False)
    transfer_date = db.Column(db.Date, nullable=False)
    reason = db.Column(db.String(300), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    old_branch = db.relationship('Branch', foreign_keys=[old_branch_id])
    new_branch = db.relationship('Branch', foreign_keys=[new_branch_id])


class EmployeeAttendance(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employee.id'), nullable=False)
    date = db.Column(db.Date, nullable=False)
    status = db.Column(db.String(20), default='Present')  # Present, Absent, Leave, Half Day
    remarks = db.Column(db.String(300), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (db.UniqueConstraint('employee_id', 'date', name='uq_employee_attendance_date'),)


class EmployeePayroll(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employee.id'), nullable=False)
    month = db.Column(db.Integer, nullable=False)  # 1-12
    year = db.Column(db.Integer, nullable=False)
    basic_pay = db.Column(db.Float, default=0.0)
    allowances = db.Column(db.Float, default=0.0)
    deductions = db.Column(db.Float, default=0.0)
    net_salary = db.Column(db.Float, default=0.0)
    payment_date = db.Column(db.Date, nullable=True)
    status = db.Column(db.String(20), default='Pending')  # Pending, Paid
    remarks = db.Column(db.String(300), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class EmployeeDocument(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employee.id'), nullable=False)
    document_name = db.Column(db.String(150), nullable=False)
    document_type = db.Column(db.String(50), default='Other')  # Aadhaar, PAN, Offer Letter, Joining Document, Other
    file_path = db.Column(db.String(400), nullable=False)
    uploaded_date = db.Column(db.DateTime, default=datetime.utcnow)


# ============================================================
# EXAM MANAGEMENT MODULE
# ============================================================
# NOTE: Exam Management reuses the canonical Branch model above
# (via the name/location synonyms) instead of its own Branch table.

class ExamType(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    language = db.Column(db.String(80), nullable=False)
    description = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(20), default='Active')  # Active / Inactive
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    branch_exams = db.relationship('BranchExam', backref='exam_type', lazy=True)


class BranchExam(db.Model):
    """Many-to-many mapping between Branch and ExamType (an exam offered at a branch)."""
    id = db.Column(db.Integer, primary_key=True)
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=False)
    exam_type_id = db.Column(db.Integer, db.ForeignKey('exam_type.id'), nullable=False)
    status = db.Column(db.String(20), default='Active')  # Active / Inactive
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    branch = db.relationship('Branch', backref='branch_exams', lazy=True)
    sessions = db.relationship('ExamSession', backref='branch_exam', lazy=True)

    __table_args__ = (
        db.UniqueConstraint('branch_id', 'exam_type_id', name='uq_branch_exam'),
    )


class ExamSession(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    branch_exam_id = db.Column(db.Integer, db.ForeignKey('branch_exam.id'), nullable=False)

    exam_date = db.Column(db.Date, nullable=False)
    start_time = db.Column(db.String(5), nullable=False)   # 'HH:MM'
    end_time = db.Column(db.String(5), nullable=False)     # 'HH:MM'
    fee = db.Column(db.Float, default=0.0)
    seat_capacity = db.Column(db.Integer, default=0)
    status = db.Column(db.String(20), default='Scheduled')  # Scheduled / Completed / Rescheduled / Cancelled

    # Reschedule audit trail (original snapshot preserved on first reschedule)
    original_date = db.Column(db.Date, nullable=True)
    original_start_time = db.Column(db.String(5), nullable=True)
    original_end_time = db.Column(db.String(5), nullable=True)
    reschedule_reason = db.Column(db.Text, nullable=True)
    rescheduled_by = db.Column(db.String(100), nullable=True)
    rescheduled_at = db.Column(db.DateTime, nullable=True)

    # Cancellation audit trail
    cancellation_reason = db.Column(db.Text, nullable=True)
    cancelled_by = db.Column(db.String(100), nullable=True)
    cancelled_at = db.Column(db.DateTime, nullable=True)

    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    session_candidates = db.relationship('SessionCandidate', backref='session', lazy=True, cascade='all, delete-orphan')

    @property
    def exam_type(self):
        return self.branch_exam.exam_type if self.branch_exam else None

    @property
    def branch(self):
        return self.branch_exam.branch if self.branch_exam else None

    @property
    def seats_taken(self):
        return len(self.session_candidates)

    @property
    def seats_available(self):
        return max(0, (self.seat_capacity or 0) - self.seats_taken)


class ExamTeam(db.Model):
    """Team/vendor group providing services for an exam."""
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    location = db.Column(db.String(200), nullable=True)
    phone = db.Column(db.String(50), nullable=True)
    exam_type_id = db.Column(db.Integer, db.ForeignKey('exam_type.id'), nullable=True)
    status = db.Column(db.String(20), default='Active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    exam_type = db.relationship('ExamType', backref='teams')
    candidates = db.relationship('Candidate', backref='team', lazy=True)


class Candidate(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    email = db.Column(db.String(150), nullable=True)
    phone = db.Column(db.String(50), nullable=True)
    register_number = db.Column(db.String(100), nullable=True)
    test_type = db.Column(db.String(100), nullable=True)
    exam_date = db.Column(db.String(20), nullable=True)
    status = db.Column(db.String(30), nullable=True, default='Registered')
    original_exam_date = db.Column(db.String(20), nullable=True)
    rescheduled_date = db.Column(db.String(20), nullable=True)
    reason_note = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Branch/Exam Center + Exam Type this candidate is registered under.
    # `test_type` above is kept in sync with exam_type.name (set on save) so
    # existing calendar/status/filter code that reads the plain-text field
    # keeps working unchanged.
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=True)
    exam_type_id = db.Column(db.Integer, db.ForeignKey('exam_type.id'), nullable=True)
    team_id = db.Column(db.Integer, db.ForeignKey('exam_team.id'), nullable=True)

    branch = db.relationship('Branch')
    exam_type = db.relationship('ExamType')

    session_links = db.relationship('SessionCandidate', backref='candidate', lazy=True)


class ExamAttempt(db.Model):
    """A single exam attempt/enrollment for a Candidate.

    A Candidate (see above) is the master profile record; every time that
    candidate registers for/sits an exam - including retests after a
    failure - a new ExamAttempt row is created instead of overwriting the
    candidate. This is what lets the Exam Activity Calendar and the
    candidate history page show the complete, permanent lifecycle of every
    exam a candidate has ever taken.

    Reuses the existing Branch and ExamType tables via FK (no duplicate
    master data). `original_scheduled_date` is captured once and never
    changed again; `scheduled_date` moves forward on every reschedule, and
    `was_rescheduled` compares the two so the calendar can show a
    "Rescheduled" marker on the original date while the current date shows
    "Scheduled" - without needing a separate stored status for it.
    """
    id = db.Column(db.Integer, primary_key=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidate.id'), nullable=False)
    exam_type_id = db.Column(db.Integer, db.ForeignKey('exam_type.id'), nullable=False)
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=False)

    # The specific Exam Session (batch/timing) this attempt is booked
    # under, if the candidate was registered against one (optional - an
    # attempt can still be created with just a branch/exam type/date and
    # no specific session, exactly as before).
    session_id = db.Column(db.Integer, db.ForeignKey('exam_session.id'), nullable=True)
    session = db.relationship('ExamSession')

    attempt_number = db.Column(db.Integer, nullable=False, default=1)

    # Scheduling dates (stored as 'YYYY-MM-DD' strings, matching the
    # existing Candidate.exam_date convention used elsewhere in this app).
    original_scheduled_date = db.Column(db.String(20), nullable=False)
    scheduled_date = db.Column(db.String(20), nullable=False)
    actual_exam_date = db.Column(db.String(20), nullable=True)

    # Scheduled / Completed / Cancelled / No Show. (A reschedule updates
    # scheduled_date and sets status back to Scheduled - see was_rescheduled
    # below for how the calendar still shows the historical "Rescheduled"
    # marker on the original date.)
    status = db.Column(db.String(20), nullable=False, default='Scheduled')
    result = db.Column(db.String(20), nullable=False, default='Pending')  # Pass / Fail / Pending

    cancellation_reason = db.Column(db.Text, nullable=True)
    reschedule_reason = db.Column(db.Text, nullable=True)
    remarks = db.Column(db.Text, nullable=True)

    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    candidate = db.relationship('Candidate', backref=db.backref(
        'attempts', lazy=True, order_by='ExamAttempt.attempt_number'))
    exam_type = db.relationship('ExamType')
    branch = db.relationship('Branch')

    @property
    def was_rescheduled(self):
        return bool(self.original_scheduled_date and self.scheduled_date
                     and self.original_scheduled_date != self.scheduled_date)


class SessionCandidate(db.Model):
    """Association of a Candidate with a specific ExamSession."""
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey('exam_session.id'), nullable=False)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidate.id'), nullable=False)
    associated_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (
        db.UniqueConstraint('session_id', 'candidate_id', name='uq_session_candidate'),
    )


class ExamAuditLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(100), default='Admin')
    action = db.Column(db.String(100), nullable=False)
    module = db.Column(db.String(100), default='Exam Management')
    record_id = db.Column(db.Integer, nullable=True)
    old_value = db.Column(db.Text, nullable=True)
    new_value = db.Column(db.Text, nullable=True)
    reason = db.Column(db.Text, nullable=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)


# ============================================================
# EXPENSE MANAGEMENT MODULE
# ============================================================
# NOTE: extends the pre-existing Expense model below instead of
# creating a duplicate. Legacy columns (category/description) are
# kept so old records and the previous UI keep working unchanged.

# ============================================================
# EXAM VOUCHER MANAGEMENT
# ============================================================
class VoucherBatch(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    batch_number = db.Column(db.String(80), unique=True, nullable=False)
    supplier = db.Column(db.String(150), nullable=True)
    purchase_date = db.Column(db.Date, nullable=False, default=datetime.utcnow)
    quantity = db.Column(db.Integer, nullable=False, default=0)
    cost_per_voucher = db.Column(db.Float, nullable=False, default=0.0)
    default_selling_price = db.Column(db.Float, nullable=False, default=0.0)
    total_cost = db.Column(db.Float, nullable=False, default=0.0)
    notes = db.Column(db.Text, nullable=True)
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=True)
    expense_id = db.Column(db.Integer, db.ForeignKey('expense.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    branch = db.relationship('Branch', backref=db.backref('voucher_batches', lazy=True))
    expense = db.relationship('Expense', backref=db.backref('voucher_batch', uselist=False))
    vouchers = db.relationship('Voucher', backref='batch', lazy=True, cascade='all, delete-orphan')


class VoucherStudent(db.Model):
    """Voucher-only student/customer master.

    This is intentionally separate from Exam Management's Candidate model.
    A person can buy a voucher without being registered for an exam session.
    """
    __tablename__ = 'voucher_student'
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(150), nullable=False)
    mobile = db.Column(db.String(30), nullable=True)
    email = db.Column(db.String(150), nullable=True)
    address = db.Column(db.String(400), nullable=True)
    id_number = db.Column(db.String(100), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    sales = db.relationship('VoucherSaleHistory', backref='voucher_student', lazy=True)


class VoucherSaleHistory(db.Model):
    """Immutable-ish sales ledger for every voucher sale."""
    __tablename__ = 'voucher_sale_history'
    id = db.Column(db.Integer, primary_key=True)
    voucher_id = db.Column(db.Integer, db.ForeignKey('voucher.id'), nullable=False)
    voucher_student_id = db.Column(db.Integer, db.ForeignKey('voucher_student.id'), nullable=False)
    # Snapshot fields preserve what was entered at the time of sale.
    student_name = db.Column(db.String(150), nullable=False)
    mobile = db.Column(db.String(30), nullable=True)
    email = db.Column(db.String(150), nullable=True)
    address = db.Column(db.String(400), nullable=True)
    id_number = db.Column(db.String(100), nullable=True)
    selling_price = db.Column(db.Float, nullable=False, default=0.0)
    discount = db.Column(db.Float, nullable=False, default=0.0)
    final_amount = db.Column(db.Float, nullable=False, default=0.0)
    paid_amount = db.Column(db.Float, nullable=False, default=0.0)
    payment_status = db.Column(db.String(20), nullable=False, default='Pending')
    payment_mode = db.Column(db.String(50), nullable=True)
    payment_reference = db.Column(db.String(150), nullable=True)
    notes = db.Column(db.Text, nullable=True)
    sold_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    voucher = db.relationship('Voucher', backref=db.backref('sale_history', lazy=True))

    @property
    def balance_amount(self):
        return max(0.0, (self.final_amount or 0.0) - (self.paid_amount or 0.0))


class Voucher(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    voucher_code = db.Column(db.String(150), unique=True, nullable=False)
    batch_id = db.Column(db.Integer, db.ForeignKey('voucher_batch.id'), nullable=False)
    purchase_cost = db.Column(db.Float, nullable=False, default=0.0)
    selling_price = db.Column(db.Float, nullable=False, default=0.0)
    status = db.Column(db.String(20), nullable=False, default='Available')  # Available/Assigned/Used/Expired/Cancelled
    student_id = db.Column(db.Integer, db.ForeignKey('candidate.id'), nullable=True)
    exam_type_id = db.Column(db.Integer, db.ForeignKey('exam_type.id'), nullable=True)
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=True)
    issued_at = db.Column(db.DateTime, nullable=True)
    used_at = db.Column(db.DateTime, nullable=True)
    payment_status = db.Column(db.String(20), nullable=False, default='Pending')  # Pending/Paid/Partial
    payment_mode = db.Column(db.String(50), nullable=True)
    payment_reference = db.Column(db.String(150), nullable=True)
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    student = db.relationship('Candidate', backref=db.backref('vouchers', lazy=True))
    exam_type = db.relationship('ExamType')
    branch = db.relationship('Branch')

    @property
    def profit(self):
        return (self.selling_price or 0) - (self.purchase_cost or 0)


class VoucherPurchaseInvoice(db.Model):
    """Financial invoice records for bulk exam-voucher purchases.

    This is intentionally separate from VoucherBatch/Voucher so invoice
    bookkeeping does not duplicate voucher inventory or assignment state.
    """
    __tablename__ = 'voucher_purchase_invoice'

    id = db.Column(db.Integer, primary_key=True)
    invoice_number = db.Column(db.String(80), unique=True, nullable=False)
    supplier = db.Column(db.String(150), nullable=False)
    invoice_date = db.Column(db.Date, nullable=False, default=datetime.utcnow)
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=False)
    payment_status = db.Column(db.String(20), nullable=False, default='Pending')
    payment_mode = db.Column(db.String(50), nullable=True)
    payment_reference = db.Column(db.String(150), nullable=True)
    subtotal = db.Column(db.Float, nullable=False, default=0.0)
    discount = db.Column(db.Float, nullable=False, default=0.0)
    tax = db.Column(db.Float, nullable=False, default=0.0)
    total_amount = db.Column(db.Float, nullable=False, default=0.0)
    paid_amount = db.Column(db.Float, nullable=False, default=0.0)
    balance_amount = db.Column(db.Float, nullable=False, default=0.0)
    notes = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(20), nullable=False, default='Active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    branch = db.relationship('Branch', backref=db.backref('voucher_purchase_invoices', lazy=True))
    items = db.relationship('VoucherPurchaseInvoiceItem', backref='invoice', lazy=True,
                            cascade='all, delete-orphan', order_by='VoucherPurchaseInvoiceItem.id')


class VoucherPurchaseInvoiceItem(db.Model):
    __tablename__ = 'voucher_purchase_invoice_item'

    id = db.Column(db.Integer, primary_key=True)
    invoice_id = db.Column(db.Integer, db.ForeignKey('voucher_purchase_invoice.id'), nullable=False)
    exam_type_id = db.Column(db.Integer, db.ForeignKey('exam_type.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False, default=1)
    unit_price = db.Column(db.Float, nullable=False, default=0.0)
    discount = db.Column(db.Float, nullable=False, default=0.0)
    tax = db.Column(db.Float, nullable=False, default=0.0)
    total_amount = db.Column(db.Float, nullable=False, default=0.0)

    exam_type = db.relationship('ExamType')


class ExpenseCategory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    status = db.Column(db.String(20), default='Active')  # Active / Inactive
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class ExpenseBudget(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    branch_id = db.Column(db.Integer, db.ForeignKey('branch.id'), nullable=True)  # null = all branches
    category_id = db.Column(db.Integer, db.ForeignKey('expense_category.id'), nullable=False)
    period_year = db.Column(db.Integer, nullable=False)
    period_month = db.Column(db.Integer, nullable=True)  # 1-12; null = whole-year budget
    budget_amount = db.Column(db.Float, default=0.0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    branch = db.relationship('Branch', backref='expense_budgets')
    category = db.relationship('ExpenseCategory', backref='budgets')

    __table_args__ = (
        db.UniqueConstraint('branch_id', 'category_id', 'period_year', 'period_month',
                             name='uq_expense_budget_period'),
    )


class ExpenseSubmissionToken(db.Model):
    """Backend idempotency guard: a unique DB constraint on `token` ensures a
    double-submitted Add Expense request can only ever insert one Expense row,
    even under concurrent/rapid duplicate POSTs (not just a JS-side disable)."""
    id = db.Column(db.Integer, primary_key=True)
    token = db.Column(db.String(64), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)