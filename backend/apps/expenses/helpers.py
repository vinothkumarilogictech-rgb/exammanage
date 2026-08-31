"""Shared helpers for the Expense Management module.

Used by both the legacy /expense-management, /expense/edit, /expense/save
routes (kept in app.py to avoid duplicating existing routes) and the new
apps/expenses/routes.py blueprint (categories, budgets, summaries, exports).
"""
import os
import uuid
from datetime import datetime, date

from flask import current_app
from werkzeug.utils import secure_filename

from apps.models import db, Expense

PAYMENT_MODES = ('Cash', 'Bank Transfer', 'UPI', 'Card', 'Other')
ALLOWED_RECEIPT_EXTENSIONS = {'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'}


def parse_date(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, '%Y-%m-%d').date()
    except ValueError:
        return None


def allowed_receipt(filename):
    return bool(filename) and '.' in filename and \
        filename.rsplit('.', 1)[1].lower() in ALLOWED_RECEIPT_EXTENSIONS


def receipt_upload_folder():
    folder = os.path.join(current_app.static_folder, 'uploads', 'expense_receipts')
    os.makedirs(folder, exist_ok=True)
    return folder


def save_receipt(uploaded_file):
    """Validates + safely stores an uploaded receipt. Returns the relative
    static path to save on the Expense row, or None if no file was given."""
    if not uploaded_file or not uploaded_file.filename:
        return None, None
    if not allowed_receipt(uploaded_file.filename):
        return None, 'Unsupported receipt file type. Allowed: PDF, JPG, PNG, DOC, DOCX.'

    safe_name = secure_filename(uploaded_file.filename)
    stored_name = f"receipt_{int(datetime.utcnow().timestamp())}_{uuid.uuid4().hex[:8]}_{safe_name}"
    uploaded_file.save(os.path.join(receipt_upload_folder(), stored_name))
    return f"uploads/expense_receipts/{stored_name}", None


def new_submission_token():
    return uuid.uuid4().hex


def consume_submission_token(token):
    """Backend duplicate-submit guard. Returns True if this token has not
    been used before (and records it), False if it's a repeat/duplicate
    submission that must NOT create a second Expense row. Relies on a
    unique DB constraint so it is safe even under concurrent requests."""
    from apps.models import ExpenseSubmissionToken
    from sqlalchemy.exc import IntegrityError

    if not token:
        # No token supplied (e.g. an old/cached form) - do not block saving,
        # just skip the idempotency check for this request.
        return True
    try:
        db.session.add(ExpenseSubmissionToken(token=token))
        db.session.flush()
        return True
    except IntegrityError:
        db.session.rollback()
        return False


def _quarter_bounds(year, quarter):
    start_month = (quarter - 1) * 3 + 1
    end_month = start_month + 2
    start = date(year, start_month, 1)
    end_month_last_day = 31 if end_month in (1, 3, 5, 7, 8, 10, 12) else (30 if end_month != 2 else 28)
    end = date(year, end_month, end_month_last_day)
    return start, end


def active_expenses_query():
    return Expense.query.filter(Expense.status != 'Cancelled')


def compute_summary_stats():
    today = date.today()
    all_active = active_expenses_query().all()

    def in_month(e, y, m):
        d = e.date_incurred.date() if hasattr(e.date_incurred, 'date') else e.date_incurred
        return d and d.year == y and d.month == m

    def in_quarter(e, y, q):
        start, end = _quarter_bounds(y, q)
        d = e.date_incurred.date() if hasattr(e.date_incurred, 'date') else e.date_incurred
        return d and start <= d <= end

    def in_year(e, y):
        d = e.date_incurred.date() if hasattr(e.date_incurred, 'date') else e.date_incurred
        return d and d.year == y

    current_quarter = (today.month - 1) // 3 + 1
    return {
        'total': sum(e.amount or 0 for e in all_active),
        'this_month': sum(e.amount or 0 for e in all_active if in_month(e, today.year, today.month)),
        'this_quarter': sum(e.amount or 0 for e in all_active if in_quarter(e, today.year, current_quarter)),
        'this_year': sum(e.amount or 0 for e in all_active if in_year(e, today.year)),
    }


def budget_alert(budget, used_amount):
    """Returns a (level, message) tuple - level is 'exceeded', 'warning', or None."""
    if not budget.budget_amount:
        return None, None
    pct = (used_amount / budget.budget_amount) * 100
    label = budget.category.name if budget.category else 'This category'
    if used_amount > budget.budget_amount:
        return 'exceeded', f'Budget exceeded for {label}.'
    if pct >= 90:
        return 'warning', f'Warning: {label} expense has reached {pct:.0f}% of the budget.'
    return None, None
