from datetime import datetime

from flask import render_template, request, redirect, url_for, session, flash

from apps import create_app, login_manager
from apps.models import User, db, Expense, Branch, ExpenseCategory, Voucher
from apps.expenses.helpers import (
    PAYMENT_MODES, parse_date, save_receipt, consume_submission_token,
    active_expenses_query, compute_summary_stats,
)

import os
from dotenv import load_dotenv

load_dotenv(override=True)

app = create_app()

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == "POST":
        username = request.form.get("username")
        password = request.form.get("password")

        if username == "admin" and password == "1234":
            return redirect(url_for("dashboard_page"))
        else:
            error = "Invalid Username or Password"

    return render_template("login.html", error=error)

@app.route('/dashboard')
def dashboard_page():
    from apps.models import ExamAttempt

    active_branch_id = session.get('active_branch_id')
    branch_query = Branch.query
    attempt_query = ExamAttempt.query
    expense_query = active_expenses_query()

    if active_branch_id:
        branch_query = branch_query.filter(Branch.id == int(active_branch_id))
        attempt_query = attempt_query.filter(ExamAttempt.branch_id == int(active_branch_id))
        expense_query = expense_query.filter(Expense.branch_id == int(active_branch_id))

    attempts = attempt_query.all()
    voucher_query = Voucher.query
    if active_branch_id:
        voucher_query = voucher_query.filter(Voucher.branch_id == int(active_branch_id))
    issued_vouchers = voucher_query.filter(Voucher.status.in_(['Assigned', 'Used'])).all()
    stats = {
        'total_branches': branch_query.count(),
        'active_branches': branch_query.filter(Branch.status == 'Active').count(),
        'scheduled_exams': sum(1 for a in attempts if a.status == 'Scheduled'),
        'completed_exams': sum(1 for a in attempts if a.status == 'Completed'),
        'expense_total': sum(e.amount or 0 for e in expense_query.all()),
        'vouchers_available': voucher_query.filter(Voucher.status == 'Available').count(),
        'vouchers_issued': len(issued_vouchers),
        'vouchers_used': sum(1 for v in issued_vouchers if v.status == 'Used'),
        'voucher_sales': sum((v.selling_price or 0) for v in issued_vouchers),
        'voucher_profit': sum((v.profit or 0) for v in issued_vouchers),
    }
    return render_template('dashboard.html', stats=stats)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for("login"))

@app.route('/expense-management')
def expense_management():
    search_term = (request.args.get('q') or '').strip()
    if request.args.get('branch_id') is not None:
        branch_id = request.args.get('branch_id', '').strip()
    else:
        active_b = session.get('active_branch_id')
        branch_id = str(active_b) if active_b else ''

    category_id = request.args.get('category_id') or ''
    payment_mode = request.args.get('payment_mode') or ''
    status = request.args.get('status') or 'All'
    date_from = request.args.get('date_from') or ''
    date_to = request.args.get('date_to') or ''

    query = Expense.query
    if search_term:
        like = f"%{search_term}%"
        query = query.filter(
            db.or_(
                Expense.category.ilike(like),
                Expense.description.ilike(like),
                Expense.payment_mode.ilike(like),
            )
        )
    if branch_id.isdigit():
        query = query.filter(Expense.branch_id == int(branch_id))
    if category_id.isdigit():
        query = query.filter(Expense.category_id == int(category_id))
    if payment_mode:
        query = query.filter(Expense.payment_mode == payment_mode)
    if status in ('Active', 'Cancelled'):
        query = query.filter(Expense.status == status)
    if date_from:
        d = parse_date(date_from)
        if d:
            query = query.filter(Expense.date_incurred >= datetime(d.year, d.month, d.day))
    if date_to:
        d = parse_date(date_to)
        if d:
            query = query.filter(Expense.date_incurred <= datetime(d.year, d.month, d.day, 23, 59, 59))

    expenses = query.order_by(Expense.date_incurred.desc()).all()
    branches = Branch.query.filter_by(status='Active').order_by(Branch.branch_name.asc()).all()
    categories = ExpenseCategory.query.filter_by(status='Active').order_by(ExpenseCategory.name.asc()).all()
    stats = compute_summary_stats()

    return render_template('expense.html', expenses=expenses, branches=branches, categories=categories,
                            payment_modes=PAYMENT_MODES, stats=stats, search_term=search_term,
                            branch_id=branch_id, category_id=category_id, payment_mode=payment_mode,
                            status=status, date_from=date_from, date_to=date_to,
                            msg=request.args.get('msg'))

@app.route('/expense')
def expense_redirect():
    return redirect(url_for('expense_management'))

@app.route('/expense/edit/<int:expense_id>', methods=['GET', 'POST'])
def expense_edit(expense_id):
    expense = Expense.query.get_or_404(expense_id)
    branches = Branch.query.filter_by(status='Active').order_by(Branch.branch_name.asc()).all()
    categories = ExpenseCategory.query.filter_by(status='Active').order_by(ExpenseCategory.name.asc()).all()

    if request.method == 'POST':
        amount_raw = request.form.get('amount') or 0
        error = None
        try:
            amount = float(amount_raw)
            if amount <= 0:
                error = 'Amount must be greater than 0.'
        except ValueError:
            error = 'Amount must be a number.'
            amount = 0

        category_id = request.form.get('category_id') or ''
        branch_id = request.form.get('branch_id') or ''
        payment_mode = request.form.get('payment_mode') or ''
        raw_date = request.form.get('date_incurred')
        date_value = parse_date(raw_date)

        if not error and not category_id.isdigit():
            error = 'Category is required.'
        if not error and not payment_mode:
            error = 'Payment Mode is required.'
        if not error and not date_value:
            error = 'A valid Expense Date is required.'

        if error:
            return render_template('expense_form.html', expense=expense, branches=branches, categories=categories,
                                    payment_modes=PAYMENT_MODES, error=error, form_data=request.form)

        category = ExpenseCategory.query.get(int(category_id))
        expense.category = category.name if category else expense.category
        expense.category_id = category.id if category else None
        expense.amount = amount
        expense.description = request.form.get('description') or request.form.get('note')
        expense.branch_id = int(branch_id) if branch_id.isdigit() else None
        expense.payment_mode = payment_mode
        expense.date_incurred = datetime(date_value.year, date_value.month, date_value.day)

        receipt_file = request.files.get('receipt')
        stored_path, upload_error = save_receipt(receipt_file)
        if upload_error:
            return render_template('expense_form.html', expense=expense, branches=branches, categories=categories,
                                    payment_modes=PAYMENT_MODES, error=upload_error, form_data=request.form)
        if stored_path:
            expense.receipt_file = stored_path

        db.session.commit()
        return redirect(url_for('expense_management', msg='Expense updated successfully.'))

    return render_template('expense_form.html', expense=expense, branches=branches, categories=categories,
                            payment_modes=PAYMENT_MODES)

@app.route('/expense/save', methods=['POST'])
def expense_save():
    expense_id = request.form.get('expense_id')
    raw_date = request.form.get('date_incurred')
    date_value = parse_date(raw_date)

    amount_raw = request.form.get('amount') or 0
    try:
        amount = float(amount_raw)
    except ValueError:
        amount = 0

    category_id = request.form.get('category_id') or ''
    branch_id = request.form.get('branch_id') or ''
    payment_mode = request.form.get('payment_mode') or ''
    category_obj = ExpenseCategory.query.get(int(category_id)) if category_id.isdigit() else None
    category_name = category_obj.name if category_obj else (request.form.get('category') or 'Other')

    if not expense_id:
        # Full validation for new expenses, checked BEFORE the idempotency
        # token is consumed so a validation failure never burns the token
        # (the same Add Expense page can be safely re-submitted).
        branches = Branch.query.filter_by(status='Active').order_by(Branch.branch_name.asc()).all()
        categories = ExpenseCategory.query.filter_by(status='Active').order_by(ExpenseCategory.name.asc()).all()
        error = None
        if amount <= 0:
            error = 'Amount must be greater than 0.'
        elif not category_id.isdigit():
            error = 'Category is required.'
        elif not branch_id.isdigit():
            error = 'Branch is required.'
        elif not payment_mode:
            error = 'Payment Mode is required.'
        elif not date_value:
            error = 'A valid Expense Date is required.'

        if error:
            return render_template('expense_form.html', branches=branches, categories=categories,
                                    payment_modes=PAYMENT_MODES, error=error, form_data=request.form,
                                    form_token=request.form.get('form_token'))

        # --- Backend duplicate-submit protection ---
        # A repeat submission with the same form_token is silently treated
        # as already-saved instead of inserting a second row.
        token = request.form.get('form_token')
        if not consume_submission_token(token):
            return redirect(url_for('expense_management', msg='Expense already saved.'))
        session.pop('expense_form_token', None)

        expense = Expense(
            category=category_name,
            category_id=category_obj.id if category_obj else None,
            amount=amount,
            description=request.form.get('description') or request.form.get('note'),
            date_incurred=datetime(date_value.year, date_value.month, date_value.day),
            branch_id=int(branch_id) if branch_id.isdigit() else None,
            payment_mode=payment_mode or None,
            status='Active',
        )
        db.session.add(expense)
        db.session.flush()

        receipt_file = request.files.get('receipt')
        stored_path, upload_error = save_receipt(receipt_file)
        if stored_path:
            expense.receipt_file = stored_path
    else:
        if amount <= 0:
            flash('Amount must be greater than 0.', 'error')
            return redirect(request.referrer or url_for('expense_management'))
        expense = Expense.query.get(int(expense_id))
        if expense:
            expense.category = category_name
            expense.category_id = category_obj.id if category_obj else expense.category_id
            expense.amount = amount
            expense.description = request.form.get('description') or request.form.get('note')
            expense.branch_id = int(branch_id) if branch_id.isdigit() else expense.branch_id
            if payment_mode:
                expense.payment_mode = payment_mode
            if date_value:
                expense.date_incurred = datetime(date_value.year, date_value.month, date_value.day)

    db.session.commit()
    return redirect(url_for('expense_management', msg='Expense saved successfully.'))

if __name__ == '__main__':
    # host='0.0.0.0' is required so the Flutter app (Android emulator via
    # 10.0.2.2, or a phone/simulator on the same Wi-Fi) can reach this
    # server. The website still works fine either way because the browser
    # runs on the same machine as Flask, but with the old default
    # (127.0.0.1-only) every request from the app - including login - just
    # times out / fails to connect.
    # app.run(host='0.0.0.0', port=5000, debug=True)
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', '0') == '1'
    app.run(host='0.0.0.0', port=port, debug=debug)
