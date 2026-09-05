import csv
import io
from datetime import datetime, date

from flask import (
    Blueprint, render_template, request, redirect, url_for, flash,
    make_response, current_app
)

from apps.models import db, Expense, Branch, ExpenseCategory, ExpenseBudget
from apps.expenses.helpers import (
    PAYMENT_MODES, parse_date, save_receipt, new_submission_token,
    consume_submission_token, active_expenses_query, compute_summary_stats,
    budget_alert, _quarter_bounds,
)

expenses_bp = Blueprint('expenses', __name__)


def _apply_expense_filters(query, search_term, branch_id, category_id, payment_mode, status, date_from, date_to):
    if search_term:
        like = f"%{search_term}%"
        query = query.filter(
            db.or_(
                Expense.category.ilike(like),
                Expense.description.ilike(like),
                Expense.payment_mode.ilike(like),
            )
        )
    if branch_id and str(branch_id).isdigit():
        query = query.filter(Expense.branch_id == int(branch_id))
    if category_id and str(category_id).isdigit():
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
            query = query.filter(Expense.date_incurred < datetime(d.year, d.month, d.day).replace(hour=23, minute=59, second=59))
    return query


def _filtered_expenses_from_args(args):
    query = _apply_expense_filters(
        Expense.query,
        (args.get('q') or '').strip(),
        args.get('branch_id') or '',
        args.get('category_id') or '',
        args.get('payment_mode') or '',
        args.get('status') or 'All',
        args.get('date_from') or '',
        args.get('date_to') or '',
    )
    return query.order_by(Expense.date_incurred.desc()).all()


# --- Add Expense (new dedicated page; POSTs to the existing /expense/save) ---

@expenses_bp.route('/expense/add')
def expense_add_page():
    branches = Branch.query.filter_by(status='Active').order_by(Branch.branch_name.asc()).all()
    categories = ExpenseCategory.query.filter_by(status='Active').order_by(ExpenseCategory.name.asc()).all()
    from flask import session
    token = new_submission_token()
    session['expense_form_token'] = token
    return render_template('expense_form.html', branches=branches, categories=categories,
                            payment_modes=PAYMENT_MODES, form_token=token)


# --- Expense Details -----------------------------------------------------

@expenses_bp.route('/expense/<int:expense_id>')
def expense_detail(expense_id):
    expense = Expense.query.get_or_404(expense_id)
    return render_template('expense_detail.html', expense=expense, msg=request.args.get('msg'))


# --- Safe Cancel (not delete) ---------------------------------------------

@expenses_bp.route('/expense/<int:expense_id>/cancel', methods=['POST'])
def expense_cancel(expense_id):
    expense = Expense.query.get_or_404(expense_id)
    expense.status = 'Cancelled'
    db.session.commit()
    flash('Expense cancelled. It has been excluded from active totals but the record is preserved.', 'success')
    return redirect(url_for('expense_detail', expense_id=expense.id))


# --- Categories ------------------------------------------------------------

@expenses_bp.route('/expense/categories', methods=['GET', 'POST'])
def expense_categories():
    if request.method == 'POST':
        name = (request.form.get('name') or '').strip()
        if not name:
            flash('Category name is required.', 'error')
        elif ExpenseCategory.query.filter(db.func.lower(ExpenseCategory.name) == name.lower()).first():
            flash(f'Category "{name}" already exists.', 'error')
        else:
            db.session.add(ExpenseCategory(name=name, status='Active'))
            db.session.commit()
            flash(f'Category "{name}" added.', 'success')
        return redirect(url_for('expenses.expense_categories'))

    categories = ExpenseCategory.query.order_by(ExpenseCategory.name.asc()).all()
    return render_template('expense_categories.html', categories=categories)


@expenses_bp.route('/expense/categories/<int:category_id>/toggle-status', methods=['POST'])
def expense_category_toggle(category_id):
    category = ExpenseCategory.query.get_or_404(category_id)
    category.status = 'Inactive' if category.status == 'Active' else 'Active'
    db.session.commit()
    return redirect(url_for('expenses.expense_categories'))


# --- Budgets & Alerts --------------------------------------------------------

@expenses_bp.route('/expense/budgets')
def expense_budgets():
    budgets = ExpenseBudget.query.order_by(ExpenseBudget.period_year.desc(), ExpenseBudget.period_month.desc()).all()
    rows = []
    for b in budgets:
        query = active_expenses_query().filter(Expense.category_id == b.category_id)
        if b.branch_id:
            query = query.filter(Expense.branch_id == b.branch_id)
        query = query.filter(Expense.date_incurred >= datetime(b.period_year, b.period_month or 1, 1))
        if b.period_month:
            end_month = b.period_month + 1
            end_year = b.period_year
            if end_month > 12:
                end_month = 1
                end_year += 1
            query = query.filter(Expense.date_incurred < datetime(end_year, end_month, 1))
        else:
            query = query.filter(Expense.date_incurred < datetime(b.period_year + 1, 1, 1))

        used = sum(e.amount or 0 for e in query.all())
        remaining = max(0.0, b.budget_amount - used)
        level, message = budget_alert(b, used)
        rows.append({'budget': b, 'used': used, 'remaining': remaining, 'alert_level': level, 'alert_message': message})

    return render_template('expense_budgets.html', rows=rows)


@expenses_bp.route('/expense/budgets/add', methods=['GET', 'POST'])
def expense_budget_add():
    branches = Branch.query.order_by(Branch.branch_name.asc()).all()
    categories = ExpenseCategory.query.filter_by(status='Active').order_by(ExpenseCategory.name.asc()).all()

    if request.method == 'POST':
        branch_id = request.form.get('branch_id') or ''
        category_id = request.form.get('category_id') or ''
        period_year = request.form.get('period_year') or ''
        period_month = request.form.get('period_month') or ''
        budget_amount = request.form.get('budget_amount') or '0'

        error = None
        if not category_id or not category_id.isdigit():
            error = 'Category is required.'
        elif not period_year or not period_year.isdigit():
            error = 'A valid year is required.'
        else:
            try:
                budget_amount_val = float(budget_amount)
                if budget_amount_val <= 0:
                    error = 'Budget amount must be greater than 0.'
            except ValueError:
                error = 'Budget amount must be a number.'

        if error:
            return render_template('expense_budget_form.html', branches=branches, categories=categories, error=error, form_data=request.form)

        existing = ExpenseBudget.query.filter_by(
            branch_id=int(branch_id) if branch_id.isdigit() else None,
            category_id=int(category_id),
            period_year=int(period_year),
            period_month=int(period_month) if period_month.isdigit() else None,
        ).first()
        if existing:
            return render_template('expense_budget_form.html', branches=branches, categories=categories,
                                    error='A budget already exists for this branch/category/period.', form_data=request.form)

        db.session.add(ExpenseBudget(
            branch_id=int(branch_id) if branch_id.isdigit() else None,
            category_id=int(category_id),
            period_year=int(period_year),
            period_month=int(period_month) if period_month.isdigit() else None,
            budget_amount=float(budget_amount),
        ))
        db.session.commit()
        return redirect(url_for('expenses.expense_budgets'))

    return render_template('expense_budget_form.html', branches=branches, categories=categories)


# --- Date / Category / Branch Expense Summary -------------------------------

@expenses_bp.route('/expense/summary')
def expense_summary():
    from flask import session
    date_from = (request.args.get('date_from') or '').strip()
    date_to = (request.args.get('date_to') or '').strip()
    category_id = (request.args.get('category_id') or '').strip()
    
    # Priority: explicit GET param > session active branch
    branch_id = request.args.get('branch_id')
    if branch_id is None:
        active_branch = session.get('active_branch_id')
        branch_id = str(active_branch) if active_branch else ''
    else:
        branch_id = branch_id.strip()

    query = active_expenses_query()

    if branch_id.isdigit():
        query = query.filter(Expense.branch_id == int(branch_id))

    if category_id.isdigit():
        query = query.filter(Expense.category_id == int(category_id))

    if date_from:
        d_from = parse_date(date_from)
        if d_from:
            query = query.filter(Expense.date_incurred >= datetime(d_from.year, d_from.month, d_from.day))

    if date_to:
        d_to = parse_date(date_to)
        if d_to:
            query = query.filter(Expense.date_incurred <= datetime(d_to.year, d_to.month, d_to.day, 23, 59, 59))

    rows = query.order_by(Expense.date_incurred.desc()).all()
    total = sum(e.amount or 0 for e in rows)

    category_breakdown = {}
    branch_breakdown = {}
    for e in rows:
        cat_name = e.expense_category.name if e.expense_category else (e.category or 'Uncategorized')
        category_breakdown[cat_name] = category_breakdown.get(cat_name, 0) + (e.amount or 0)
        branch_name = e.branch.branch_name if e.branch else 'Unassigned'
        branch_breakdown[branch_name] = branch_breakdown.get(branch_name, 0) + (e.amount or 0)

    branches = Branch.query.order_by(Branch.branch_name.asc()).all()
    categories = ExpenseCategory.query.filter_by(status='Active').order_by(ExpenseCategory.name.asc()).all()

    # Build descriptive label
    label_parts = []
    if date_from and date_to:
        label_parts.append(f"{date_from} to {date_to}")
    elif date_from:
        label_parts.append(f"From {date_from}")
    elif date_to:
        label_parts.append(f"Until {date_to}")
    else:
        label_parts.append("All Recorded Dates")

    if category_id.isdigit():
        cat_obj = ExpenseCategory.query.get(int(category_id))
        if cat_obj:
            label_parts.append(f"Category: {cat_obj.name}")

    if branch_id.isdigit():
        br_obj = Branch.query.get(int(branch_id))
        if br_obj:
            label_parts.append(f"Branch: {br_obj.branch_name}")

    label = " • ".join(label_parts)

    return render_template(
        'expense_summary.html',
        date_from=date_from,
        date_to=date_to,
        category_id=category_id,
        branch_id=branch_id,
        branches=branches,
        categories=categories,
        label=label,
        total=total,
        category_breakdown=sorted(category_breakdown.items(), key=lambda x: -x[1]),
        branch_breakdown=sorted(branch_breakdown.items(), key=lambda x: -x[1]),
        expenses=rows,
    )



# --- PDF Export --------------------------------------------------------------

@expenses_bp.route('/expense/export/pdf')
def expense_export_pdf():
    rows = _filtered_expenses_from_args(request.args)
    total = sum(e.amount or 0 for e in rows if e.status != 'Cancelled')
    generated_at = datetime.utcnow().strftime('%d %b %Y, %H:%M UTC')
    filters = {
        'branch': Branch.query.get(int(request.args['branch_id'])).branch_name
                  if request.args.get('branch_id', '').isdigit() else 'All Branches',
        'date_from': request.args.get('date_from') or '-',
        'date_to': request.args.get('date_to') or '-',
        'status': request.args.get('status') or 'All',
    }

    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib import colors
        from reportlab.lib.units import mm
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib.styles import getSampleStyleSheet

        buf = io.BytesIO()
        doc = SimpleDocTemplate(buf, pagesize=A4)
        styles = getSampleStyleSheet()
        elements = [
            Paragraph('Expense Report', styles['Title']),
            Paragraph(f"Branch: {filters['branch']} | From: {filters['date_from']} To: {filters['date_to']}", styles['Normal']),
            Paragraph(f"Generated: {generated_at}", styles['Normal']),
            Spacer(1, 10 * mm),
        ]
        data = [['Date', 'Branch', 'Category', 'Amount', 'Payment Mode']]
        for e in rows:
            data.append([
                e.date_incurred.strftime('%d-%b-%Y') if e.date_incurred else '-',
                e.branch.branch_name if e.branch else '-',
                e.expense_category.name if e.expense_category else e.category,
                f"{e.amount:.2f}",
                e.payment_mode or '-',
            ])
        data.append(['', '', '', f"Total: {total:.2f}", ''])
        table = Table(data, repeatRows=1)
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#7c3aed')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTSIZE', (0, 0), (-1, -1), 8),
            ('GRID', (0, 0), (-1, -2), 0.5, colors.grey),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ]))
        elements.append(table)
        doc.build(elements)

        response = make_response(buf.getvalue())
        response.headers['Content-Type'] = 'application/pdf'
        response.headers['Content-Disposition'] = 'attachment; filename=expense_report.pdf'
        return response
    except ImportError:
        # reportlab isn't installed - fall back to a clean print-friendly HTML
        # page. The user can still save it as a PDF via the browser's Print
        # dialog. `pip install reportlab` enables true PDF generation.
        return render_template('expense_export_print.html', expenses=rows, total=total,
                                filters=filters, generated_at=generated_at)


# --- Excel Export --------------------------------------------------------------

@expenses_bp.route('/expense/export/excel')
def expense_export_excel():
    rows = _filtered_expenses_from_args(request.args)
    total = sum(e.amount or 0 for e in rows if e.status != 'Cancelled')
    columns = ['Expense ID', 'Date', 'Branch', 'Category', 'Amount', 'Payment Mode', 'Note']

    try:
        from openpyxl import Workbook

        wb = Workbook()
        ws = wb.active
        ws.title = 'Expenses'
        ws.append(columns)
        for e in rows:
            ws.append([
                f"EXP-{e.id:03d}",
                e.date_incurred.strftime('%Y-%m-%d') if e.date_incurred else '',
                e.branch.branch_name if e.branch else '',
                e.expense_category.name if e.expense_category else e.category,
                e.amount or 0,
                e.payment_mode or '',
                e.description or '',
            ])
        ws.append(['', '', '', '', total, '', 'Total'])

        buf = io.BytesIO()
        wb.save(buf)
        response = make_response(buf.getvalue())
        response.headers['Content-Type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        response.headers['Content-Disposition'] = 'attachment; filename=expense_report.xlsx'
        return response
    except ImportError:
        # openpyxl isn't installed - fall back to CSV, which Excel opens
        # natively. `pip install openpyxl` enables true .xlsx generation.
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(columns)
        for e in rows:
            writer.writerow([
                f"EXP-{e.id:03d}",
                e.date_incurred.strftime('%Y-%m-%d') if e.date_incurred else '',
                e.branch.branch_name if e.branch else '',
                e.expense_category.name if e.expense_category else e.category,
                e.amount or 0,
                e.payment_mode or '',
                e.description or '',
            ])
        writer.writerow(['', '', '', '', total, '', 'Total'])
        response = make_response(buf.getvalue())
        response.headers['Content-Type'] = 'text/csv'
        response.headers['Content-Disposition'] = 'attachment; filename=expense_report.csv'
        return response
