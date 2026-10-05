import csv
import io
from datetime import date, datetime
from uuid import uuid4
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, jsonify, Response
from apps.models import (
    db, VoucherBatch, Voucher, VoucherStudent, VoucherSaleHistory,
    Candidate, ExamType, Branch, Expense, ExpenseCategory
)

vouchers_bp = Blueprint('vouchers', __name__, url_prefix='/vouchers')

STATUSES = ['Available', 'Sold', 'Assigned', 'Used', 'Expired', 'Cancelled']
PAYMENT_STATUSES = ['Paid', 'Pending', 'Partial']
PAYMENT_MODES = ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Other']


def _get_active_branch_id():
    bid = request.args.get('branch_id')
    if bid and str(bid).isdigit():
        return int(bid)
    sess_bid = session.get('active_branch_id')
    if sess_bid and str(sess_bid).isdigit():
        return int(sess_bid)
    return None


def _compute_voucher_stats(branch_id=None):
    q = Voucher.query
    if branch_id:
        q = q.filter(Voucher.branch_id == branch_id)

    available = q.filter(Voucher.status == 'Available').count()
    sold_rows = q.filter(Voucher.status.in_(['Sold', 'Assigned', 'Used'])).all()
    used = q.filter(Voucher.status == 'Used').count()
    expired = q.filter(Voucher.status == 'Expired').count()
    cancelled = q.filter(Voucher.status == 'Cancelled').count()

    batches = VoucherBatch.query
    if branch_id:
        batches = batches.filter(VoucherBatch.branch_id == branch_id)

    purchased = int(batches.with_entities(db.func.coalesce(db.func.sum(VoucherBatch.quantity), 0)).scalar() or 0)
    purchase_cost = float(batches.with_entities(db.func.coalesce(db.func.sum(VoucherBatch.total_cost), 0)).scalar() or 0)

    history_q = VoucherSaleHistory.query.join(Voucher)
    if branch_id:
        history_q = history_q.filter(Voucher.branch_id == branch_id)
    histories = history_q.all()

    sales_revenue = sum(float(h.final_amount or 0) for h in histories)
    cost_of_sold = sum(float(h.voucher.purchase_cost or 0) for h in histories if h.voucher)
    pending_amount = sum(float(h.balance_amount or 0) for h in histories)

    # Legacy fallback: any sold vouchers not yet in VoucherSaleHistory
    history_voucher_ids = {h.voucher_id for h in histories}
    for v in sold_rows:
        if v.id not in history_voucher_ids:
            sales_revenue += float(v.selling_price or 0)
            cost_of_sold += float(v.purchase_cost or 0)

    realized_profit = sales_revenue - cost_of_sold
    stock_value = sum(float(v.purchase_cost or 0) for v in q.filter(Voucher.status == 'Available').all())
    sale_count = len(histories) + len([v for v in sold_rows if v.id not in history_voucher_ids])

    return {
        'purchased': purchased,
        'available': available,
        'issued': len(sold_rows),
        'sold': len(sold_rows),
        'used': used,
        'expired': expired,
        'cancelled': cancelled,
        'purchase_cost': purchase_cost,
        'sales_revenue': sales_revenue,
        'realized_profit': realized_profit,
        'stock_value': stock_value,
        'pending_amount': pending_amount,
        'sale_count': sale_count,
        # backward compatibility keys
        'sales': sales_revenue,
        'profit': realized_profit,
    }


def _normalize_voucher_row(v):
    sales = sorted(v.sale_history or [], key=lambda x: x.sold_at or datetime.min, reverse=True)
    latest_sale = sales[0] if sales else None

    student_name = '-'
    mobile = '-'
    email = '-'
    id_number = '-'
    address = '-'
    final_amount = float(v.selling_price or 0)
    paid_amount = float(v.selling_price or 0) if v.payment_status == 'Paid' else 0.0
    balance_amount = 0.0
    discount = 0.0
    payment_status = v.payment_status or 'Pending'
    payment_mode = v.payment_mode or 'Cash'
    payment_reference = v.payment_reference or '-'
    notes = v.notes or ''
    sold_at = v.issued_at

    if latest_sale:
        student_name = latest_sale.student_name or '-'
        mobile = latest_sale.mobile or '-'
        email = latest_sale.email or '-'
        id_number = latest_sale.id_number or '-'
        address = latest_sale.address or '-'
        final_amount = float(latest_sale.final_amount or 0)
        paid_amount = float(latest_sale.paid_amount or 0)
        balance_amount = float(latest_sale.balance_amount or 0)
        discount = float(latest_sale.discount or 0)
        payment_status = latest_sale.payment_status or payment_status
        payment_mode = latest_sale.payment_mode or payment_mode
        payment_reference = latest_sale.payment_reference or payment_reference
        notes = latest_sale.notes or notes
        sold_at = latest_sale.sold_at or sold_at
    elif v.student:
        student_name = v.student.name or '-'
        mobile = v.student.phone or '-'
        email = v.student.email or '-'

    exam_type_name = v.exam_type.name if v.exam_type else '-'

    return {
        'id': v.id,
        'voucher_code': v.voucher_code,
        'status': 'Sold' if v.status == 'Assigned' else v.status,
        'raw_status': v.status,
        'purchase_cost': float(v.purchase_cost or 0),
        'selling_price': float(v.selling_price or 0),
        'profit': float(v.profit or 0),
        'exam_type_name': exam_type_name,
        'exam_type_id': v.exam_type_id,
        'branch_id': v.branch_id,
        'branch_name': v.branch.branch_name if v.branch else '-',
        'batch_id': v.batch_id,
        'batch_number': v.batch.batch_number if v.batch else '-',
        'supplier': v.batch.supplier if v.batch else '-',
        'purchase_date': v.batch.purchase_date if v.batch else None,
        'issued_at': v.issued_at,
        'used_at': v.used_at,
        'sold_at': sold_at,
        'student_name': student_name,
        'mobile': mobile,
        'email': email,
        'id_number': id_number,
        'address': address,
        'final_amount': final_amount,
        'paid_amount': paid_amount,
        'balance_amount': balance_amount,
        'discount': discount,
        'payment_status': payment_status,
        'payment_mode': payment_mode,
        'payment_reference': payment_reference,
        'notes': notes,
        'sale_id': latest_sale.id if latest_sale else None,
    }


@vouchers_bp.route('/')
def dashboard():
    branch_id = _get_active_branch_id()
    active_tab = request.args.get('tab', 'overview').strip().lower()
    search_q = (request.args.get('q') or '').strip().lower()
    exam_type_filter = (request.args.get('exam_type_id') or '').strip()
    status_filter = (request.args.get('status') or '').strip()
    date_filter = (request.args.get('date') or '').strip()

    stats = _compute_voucher_stats(branch_id)

    # Lookups
    branches = Branch.query.filter_by(status='Active').order_by(Branch.branch_name.asc()).all()
    exam_types = ExamType.query.filter_by(status='Active').order_by(ExamType.name.asc()).all()
    candidates = Candidate.query.order_by(Candidate.name.asc()).all()

    # Base voucher query
    vq = Voucher.query
    if branch_id:
        vq = vq.filter(Voucher.branch_id == branch_id)

    all_vouchers_raw = vq.order_by(Voucher.id.desc()).all()
    all_normalized = [_normalize_voucher_row(v) for v in all_vouchers_raw]

    # Available Vouchers
    available_vouchers = [v for v in all_normalized if v['status'] == 'Available']

    # Grouped by Exam Type (matching Flutter available_vouchers_screen.dart)
    exam_groups = {}
    for v in available_vouchers:
        exam_name = v['exam_type_name'] if v['exam_type_name'] != '-' else 'Unassigned Exam'
        exam_groups.setdefault(exam_name, []).append(v)
    sorted_exam_groups = dict(sorted(exam_groups.items(), key=lambda x: x[0].lower()))

    # Sold Vouchers
    sold_vouchers_all = [v for v in all_normalized if v['status'] in ('Sold', 'Assigned', 'Used')]
    filtered_sold = sold_vouchers_all

    if search_q:
        filtered_sold = [
            v for v in filtered_sold
            if search_q in v['student_name'].lower()
            or search_q in v['mobile'].lower()
            or search_q in v['voucher_code'].lower()
        ]
    if exam_type_filter:
        filtered_sold = [v for v in filtered_sold if str(v['exam_type_id']) == exam_type_filter]
    if status_filter and status_filter != 'All':
        if status_filter == 'Used':
            filtered_sold = [v for v in filtered_sold if v['status'] == 'Used']
        elif status_filter in ('Paid', 'Pending', 'Partial'):
            filtered_sold = [v for v in filtered_sold if v['payment_status'] == status_filter]

    # Sales History Query
    hq = VoucherSaleHistory.query.join(Voucher)
    if branch_id:
        hq = hq.filter(Voucher.branch_id == branch_id)
    all_history = hq.order_by(VoucherSaleHistory.sold_at.desc(), VoucherSaleHistory.id.desc()).all()

    filtered_history = all_history
    if date_filter:
        try:
            target_date = datetime.strptime(date_filter, '%Y-%m-%d').date()
            filtered_history = [
                h for h in filtered_history
                if h.sold_at and h.sold_at.date() == target_date
            ]
        except ValueError:
            pass

    if search_q and active_tab == 'history':
        filtered_history = [
            h for h in filtered_history
            if search_q in (h.student_name or '').lower()
            or search_q in (h.mobile or '').lower()
            or search_q in (h.voucher.voucher_code if h.voucher else '').lower()
        ]
    if exam_type_filter and active_tab == 'history':
        filtered_history = [
            h for h in filtered_history
            if h.voucher and str(h.voucher.exam_type_id) == exam_type_filter
        ]

    # Purchase Batches Query
    bq = VoucherBatch.query
    if branch_id:
        bq = bq.filter(VoucherBatch.branch_id == branch_id)
    batches = bq.order_by(VoucherBatch.purchase_date.desc(), VoucherBatch.id.desc()).all()

    batch_cards = []
    for b in batches:
        v_in_batch = b.vouchers or []
        avail_count = sum(1 for v in v_in_batch if v.status == 'Available')
        sold_cnt = sum(1 for v in v_in_batch if v.status in ('Sold', 'Assigned', 'Used'))
        used_cnt = sum(1 for v in v_in_batch if v.status == 'Used')
        exam_name = '-'
        if v_in_batch and v_in_batch[0].exam_type:
            exam_name = v_in_batch[0].exam_type.name
        batch_cards.append({
            'id': b.id,
            'batch_number': b.batch_number,
            'supplier': b.supplier or '-',
            'purchase_date': b.purchase_date,
            'quantity': b.quantity,
            'cost_per_voucher': b.cost_per_voucher,
            'default_selling_price': b.default_selling_price,
            'total_cost': b.total_cost,
            'branch_name': b.branch.branch_name if b.branch else '-',
            'expense_id': b.expense_id,
            'exam_name': exam_name,
            'available_count': avail_count,
            'sold_count': sold_cnt,
            'used_count': used_cnt,
            'notes': b.notes or '',
        })

    # Student-Wise History
    # Group by VoucherStudent / Candidate
    student_map = {}
    for h in all_history:
        key = h.voucher_student_id or f"name_{h.student_name}"
        item = student_map.setdefault(key, {
            'student_id': h.voucher_student_id,
            'name': h.student_name,
            'mobile': h.mobile or '-',
            'email': h.email or '-',
            'address': h.address or '-',
            'id_number': h.id_number or '-',
            'vouchers_count': 0,
            'total_spent': 0.0,
            'total_profit': 0.0,
            'used_count': 0,
            'sales': [],
        })
        item['vouchers_count'] += 1
        item['total_spent'] += float(h.final_amount or 0)
        cost = float(h.voucher.purchase_cost or 0) if h.voucher else 0.0
        item['total_profit'] += (float(h.final_amount or 0) - cost)
        if h.voucher and h.voucher.status == 'Used':
            item['used_count'] += 1
        item['sales'].append(h)

    # Legacy assigned vouchers fallback
    for v in sold_vouchers_all:
        if v['student_name'] != '-' and v['sale_id'] is None:
            key = f"legacy_{v['student_name']}"
            item = student_map.setdefault(key, {
                'student_id': None,
                'name': v['student_name'],
                'mobile': v['mobile'],
                'email': v['email'],
                'address': v['address'],
                'id_number': v['id_number'],
                'vouchers_count': 0,
                'total_spent': 0.0,
                'total_profit': 0.0,
                'used_count': 0,
                'sales': [],
            })
            item['vouchers_count'] += 1
            item['total_spent'] += v['final_amount']
            item['total_profit'] += v['profit']
            if v['status'] == 'Used':
                item['used_count'] += 1

    students_list = sorted(student_map.values(), key=lambda x: x['name'].lower())

    return render_template(
        'voucher_dashboard.html',
        stats=stats,
        branches=branches,
        exam_types=exam_types,
        candidates=candidates,
        active_branch_id=branch_id,
        active_tab=active_tab,
        search_q=search_q,
        exam_type_filter=exam_type_filter,
        status_filter=status_filter,
        date_filter=date_filter,
        available_vouchers=available_vouchers,
        exam_groups=sorted_exam_groups,
        sold_vouchers=filtered_sold,
        total_sold_count=len(sold_vouchers_all),
        sales_history=filtered_history,
        total_history_count=len(all_history),
        batches=batch_cards,
        students=students_list,
    )


@vouchers_bp.route('/purchase', methods=['GET', 'POST'])
def purchase():
    branches = Branch.query.filter_by(status='Active').order_by(Branch.branch_name.asc()).all()
    exam_types = ExamType.query.filter_by(status='Active').order_by(ExamType.name.asc()).all()

    if request.method == 'POST':
        try:
            quantity = int(request.form.get('quantity') or 0)
            cost = float(request.form.get('cost_per_voucher') or 0)
            selling = float(request.form.get('selling_price') or 0)
        except (ValueError, TypeError):
            quantity, cost, selling = 0, 0, 0

        exam_type_id = request.form.get('exam_type_id')
        if not exam_type_id or not str(exam_type_id).isdigit():
            flash('Exam type is required.', 'error')
            return render_template('voucher_purchase.html', branches=branches, exam_types=exam_types, form_data=request.form)

        exam = ExamType.query.get(int(exam_type_id))
        if not exam:
            flash('Selected exam type not found.', 'error')
            return render_template('voucher_purchase.html', branches=branches, exam_types=exam_types, form_data=request.form)

        if quantity <= 0 or cost <= 0 or selling < 0:
            flash('Quantity and purchase cost must be greater than 0.', 'error')
            return render_template('voucher_purchase.html', branches=branches, exam_types=exam_types, form_data=request.form)

        codes_text = request.form.get('voucher_codes') or ''
        custom_codes = [x.strip() for x in codes_text.splitlines() if x.strip()]
        if custom_codes and len(custom_codes) != quantity:
            flash(f'You entered {len(custom_codes)} custom codes, but quantity is {quantity}. Count must match.', 'error')
            return render_template('voucher_purchase.html', branches=branches, exam_types=exam_types, form_data=request.form)

        if not custom_codes:
            prefix = (request.form.get('code_prefix') or 'VCH').strip().upper() or 'VCH'
            codes = []
            while len(codes) < quantity:
                candidate_code = f'{prefix}-{datetime.utcnow().strftime("%Y%m%d")}-{uuid4().hex[:8].upper()}'
                if not Voucher.query.filter_by(voucher_code=candidate_code).first() and candidate_code not in codes:
                    codes.append(candidate_code)
        else:
            codes = custom_codes

        duplicate = Voucher.query.filter(Voucher.voucher_code.in_(codes)).first()
        if duplicate:
            flash(f'One or more voucher codes already exist: {duplicate.voucher_code}', 'error')
            return render_template('voucher_purchase.html', branches=branches, exam_types=exam_types, form_data=request.form)

        bid = request.form.get('branch_id') or (_get_active_branch_id() or '')
        branch_id = int(bid) if str(bid).isdigit() else None

        p_date_str = request.form.get('purchase_date')
        try:
            purchase_date = datetime.strptime(p_date_str, '%Y-%m-%d').date() if p_date_str else date.today()
        except ValueError:
            purchase_date = date.today()

        batch_no = f'VB-{datetime.utcnow().strftime("%Y%m%d%H%M%S%f")}'
        batch = VoucherBatch(
            batch_number=batch_no,
            supplier=request.form.get('supplier') or None,
            purchase_date=purchase_date,
            quantity=quantity,
            cost_per_voucher=cost,
            default_selling_price=selling,
            total_cost=quantity * cost,
            notes=request.form.get('notes') or None,
            branch_id=branch_id,
        )
        db.session.add(batch)
        db.session.flush()

        # Dedicated expense entry matching Flutter architecture
        cat = ExpenseCategory.query.filter(db.func.lower(ExpenseCategory.name) == 'exam voucher purchase').first()
        if not cat:
            cat = ExpenseCategory(name='Exam Voucher Purchase', status='Active')
            db.session.add(cat)
            db.session.flush()

        expense = Expense(
            category=cat.name,
            category_id=cat.id,
            amount=quantity * cost,
            description=f'Bulk exam voucher purchase - {batch_no} ({quantity} vouchers, {exam.name})',
            date_incurred=datetime.combine(batch.purchase_date, datetime.min.time()),
            branch_id=branch_id,
            payment_mode=request.form.get('payment_mode') or 'Other',
            status='Active'
        )
        db.session.add(expense)
        db.session.flush()
        batch.expense_id = expense.id

        # Insert all vouchers
        for code in codes:
            db.session.add(Voucher(
                voucher_code=code,
                batch_id=batch.id,
                purchase_cost=cost,
                selling_price=selling,
                branch_id=branch_id,
                exam_type_id=exam.id,
                status='Available'
            ))

        db.session.commit()
        flash(f'{quantity} vouchers purchased successfully under Batch {batch_no}. Expense ₹{quantity * cost:,.2f} recorded.', 'success')
        return redirect(url_for('vouchers.dashboard', tab='batches'))

    return render_template('voucher_purchase.html', branches=branches, exam_types=exam_types, form_data={})


@vouchers_bp.route('/sell', methods=['POST'])
@vouchers_bp.route('/assign', methods=['GET', 'POST'])
def sell():
    if request.method == 'GET':
        branch_id = _get_active_branch_id()
        available = Voucher.query.filter_by(status='Available')
        if branch_id:
            available = available.filter(Voucher.branch_id == branch_id)
        available_vouchers = available.order_by(Voucher.id.desc()).all()
        students = Candidate.query.order_by(Candidate.name.asc()).all()
        exams = ExamType.query.filter_by(status='Active').order_by(ExamType.name.asc()).all()
        return render_template('voucher_assign.html', available=available_vouchers, students=students, exams=exams)

    # POST workflow (Sell Voucher matching Flutter)
    voucher_id = request.form.get('voucher_id')
    if not voucher_id or not str(voucher_id).isdigit():
        flash('Please select an available voucher.', 'error')
        return redirect(request.referrer or url_for('vouchers.dashboard'))

    voucher = Voucher.query.get_or_404(int(voucher_id))
    if voucher.status != 'Available':
        flash('The selected voucher is no longer available.', 'error')
        return redirect(request.referrer or url_for('vouchers.dashboard'))

    student_name = (request.form.get('student_name') or '').strip()
    if not student_name:
        flash('Student / Candidate full name is required.', 'error')
        return redirect(request.referrer or url_for('vouchers.dashboard'))

    mobile = (request.form.get('mobile') or '').strip() or None
    email = (request.form.get('email') or '').strip() or None
    address = (request.form.get('address') or '').strip() or None
    id_number = (request.form.get('id_number') or '').strip() or None

    try:
        selling_price = float(request.form.get('selling_price') or voucher.selling_price or 0)
        discount = float(request.form.get('discount') or 0)
    except (ValueError, TypeError):
        selling_price, discount = float(voucher.selling_price or 0), 0.0

    if selling_price < 0 or discount < 0 or discount > selling_price:
        flash('Selling price and discount must be valid (discount cannot exceed price).', 'error')
        return redirect(request.referrer or url_for('vouchers.dashboard'))

    final_amount = max(0.0, selling_price - discount)

    payment_status = (request.form.get('payment_status') or 'Paid').strip()
    if payment_status not in PAYMENT_STATUSES:
        payment_status = 'Paid'

    payment_mode = (request.form.get('payment_mode') or 'Cash').strip()

    try:
        if payment_status == 'Paid':
            paid_amount = final_amount
        elif payment_status == 'Pending':
            paid_amount = 0.0
        elif payment_status == 'Partial':
            paid_amount = float(request.form.get('paid_amount') or 0)
            if paid_amount <= 0 or paid_amount >= final_amount:
                flash('For Partial payment, paid amount must be greater than 0 and less than final amount.', 'error')
                return redirect(request.referrer or url_for('vouchers.dashboard'))
        else:
            paid_amount = final_amount
    except (ValueError, TypeError):
        paid_amount = final_amount

    payment_reference = (request.form.get('payment_reference') or '').strip() or None
    notes = (request.form.get('notes') or '').strip() or None

    # Check for existing VoucherStudent by mobile or email
    student = None
    if mobile:
        student = VoucherStudent.query.filter(VoucherStudent.mobile == mobile).first()
    if not student and email:
        student = VoucherStudent.query.filter(VoucherStudent.email == email).first()

    if not student:
        student = VoucherStudent(
            full_name=student_name,
            mobile=mobile,
            email=email,
            address=address,
            id_number=id_number
        )
        db.session.add(student)
        db.session.flush()
    else:
        student.full_name = student_name
        if mobile: student.mobile = mobile
        if email: student.email = email
        if address: student.address = address
        if id_number: student.id_number = id_number

    # Link Candidate if matching name or candidate_id provided
    candidate_id = request.form.get('candidate_id')
    if candidate_id and str(candidate_id).isdigit():
        voucher.student_id = int(candidate_id)

    sold_at = datetime.utcnow()
    history = VoucherSaleHistory(
        voucher_id=voucher.id,
        voucher_student_id=student.id,
        student_name=student_name,
        mobile=mobile,
        email=email,
        address=address,
        id_number=id_number,
        selling_price=selling_price,
        discount=discount,
        final_amount=final_amount,
        paid_amount=paid_amount,
        payment_status=payment_status,
        payment_mode=payment_mode,
        payment_reference=payment_reference,
        notes=notes,
        sold_at=sold_at,
    )
    db.session.add(history)

    # Update voucher status and fields
    voucher.status = 'Sold'
    voucher.issued_at = sold_at
    voucher.selling_price = selling_price
    voucher.payment_status = payment_status
    voucher.payment_mode = payment_mode
    voucher.payment_reference = payment_reference
    voucher.notes = notes

    db.session.commit()
    flash(f'Voucher {voucher.voucher_code} sold to {student_name} successfully for ₹{final_amount:,.2f}.', 'success')
    return redirect(url_for('vouchers.dashboard', tab='sold'))


@vouchers_bp.route('/<int:voucher_id>/payment', methods=['POST'])
def update_payment(voucher_id):
    voucher = Voucher.query.get_or_404(voucher_id)
    latest = VoucherSaleHistory.query.filter_by(voucher_id=voucher.id).order_by(
        VoucherSaleHistory.sold_at.desc(), VoucherSaleHistory.id.desc()
    ).first()

    if not latest:
        flash('This voucher has no sale history to update.', 'error')
        return redirect(request.referrer or url_for('vouchers.dashboard', tab='sold'))

    payment_status = request.form.get('payment_status') or latest.payment_status
    if payment_status not in PAYMENT_STATUSES:
        flash('Invalid payment status.', 'error')
        return redirect(request.referrer or url_for('vouchers.dashboard', tab='sold'))

    try:
        if payment_status == 'Paid':
            paid_amount = latest.final_amount
        elif payment_status == 'Pending':
            paid_amount = 0.0
        elif payment_status == 'Partial':
            paid_amount = float(request.form.get('paid_amount') or 0)
            if paid_amount <= 0 or paid_amount >= latest.final_amount:
                flash('For Partial payment, paid amount must be between 0 and final amount.', 'error')
                return redirect(request.referrer or url_for('vouchers.dashboard', tab='sold'))
        else:
            paid_amount = latest.paid_amount
    except (ValueError, TypeError):
        paid_amount = latest.paid_amount

    payment_mode = request.form.get('payment_mode') or latest.payment_mode
    payment_reference = request.form.get('payment_reference') or latest.payment_reference
    notes = request.form.get('notes') or latest.notes

    latest.payment_status = payment_status
    latest.paid_amount = paid_amount
    latest.payment_mode = payment_mode
    latest.payment_reference = payment_reference
    latest.notes = notes

    voucher.payment_status = payment_status
    voucher.payment_mode = payment_mode
    voucher.payment_reference = payment_reference
    voucher.notes = notes

    db.session.commit()
    flash(f'Payment updated for voucher {voucher.voucher_code}.', 'success')
    return redirect(request.referrer or url_for('vouchers.dashboard', tab='sold'))


@vouchers_bp.route('/<int:voucher_id>/use', methods=['POST'])
def use(voucher_id):
    voucher = Voucher.query.get_or_404(voucher_id)
    if voucher.status not in ('Sold', 'Assigned'):
        flash('Only sold/assigned vouchers can be marked as used.', 'error')
    else:
        voucher.status = 'Used'
        voucher.used_at = datetime.utcnow()
        db.session.commit()
        flash(f'Voucher {voucher.voucher_code} marked as used.', 'success')
    return redirect(request.referrer or url_for('vouchers.dashboard', tab='sold'))


@vouchers_bp.route('/<int:voucher_id>/cancel', methods=['POST'])
def cancel(voucher_id):
    voucher = Voucher.query.get_or_404(voucher_id)
    if voucher.status == 'Used':
        flash('A used voucher cannot be cancelled.', 'error')
    else:
        voucher.status = 'Cancelled'
        db.session.commit()
        flash(f'Voucher {voucher.voucher_code} cancelled.', 'info')
    return redirect(request.referrer or url_for('vouchers.dashboard'))


@vouchers_bp.route('/<int:voucher_id>')
def detail(voucher_id):
    voucher = Voucher.query.get_or_404(voucher_id)
    norm = _normalize_voucher_row(voucher)
    history = sorted(voucher.sale_history or [], key=lambda x: x.sold_at or datetime.min, reverse=True)
    return render_template('voucher_detail.html', voucher=voucher, v=norm, history=history)


@vouchers_bp.route('/<int:voucher_id>/json')
def voucher_json(voucher_id):
    voucher = Voucher.query.get_or_404(voucher_id)
    norm = _normalize_voucher_row(voucher)
    history = [
        {
            'id': h.id,
            'student_name': h.student_name,
            'mobile': h.mobile or '-',
            'email': h.email or '-',
            'selling_price': h.selling_price,
            'discount': h.discount,
            'final_amount': h.final_amount,
            'paid_amount': h.paid_amount,
            'balance_amount': h.balance_amount,
            'payment_status': h.payment_status,
            'payment_mode': h.payment_mode or '-',
            'payment_reference': h.payment_reference or '-',
            'notes': h.notes or '',
            'sold_at': h.sold_at.strftime('%d-%b-%Y %H:%M') if h.sold_at else '-',
        }
        for h in sorted(voucher.sale_history or [], key=lambda x: x.sold_at or datetime.min, reverse=True)
    ]
    return jsonify({
        'success': True,
        'voucher': norm,
        'history': history,
        'purchase': {
            'batch_number': voucher.batch.batch_number if voucher.batch else '-',
            'supplier': voucher.batch.supplier if voucher.batch else '-',
            'purchase_date': voucher.batch.purchase_date.strftime('%d-%b-%Y') if voucher.batch and voucher.batch.purchase_date else '-',
            'purchase_cost': voucher.purchase_cost,
            'selling_price': voucher.selling_price,
            'branch_name': voucher.branch.branch_name if voucher.branch else '-',
        }
    })


@vouchers_bp.route('/batch/<int:batch_id>/json')
def batch_json(batch_id):
    batch = VoucherBatch.query.get_or_404(batch_id)
    vouchers = [
        {
            'id': v.id,
            'voucher_code': v.voucher_code,
            'status': 'Sold' if v.status == 'Assigned' else v.status,
            'purchase_cost': v.purchase_cost,
            'selling_price': v.selling_price,
            'exam_type_name': v.exam_type.name if v.exam_type else '-',
        }
        for v in (batch.vouchers or [])
    ]
    return jsonify({
        'success': True,
        'batch_number': batch.batch_number,
        'supplier': batch.supplier or '-',
        'purchase_date': batch.purchase_date.strftime('%d-%b-%Y') if batch.purchase_date else '-',
        'quantity': batch.quantity,
        'total_cost': batch.total_cost,
        'vouchers': vouchers,
    })


@vouchers_bp.route('/history/export-csv')
def export_history_csv():
    branch_id = _get_active_branch_id()
    date_filter = request.args.get('date', '').strip()
    search_q = request.args.get('q', '').strip().lower()
    exam_type_filter = request.args.get('exam_type_id', '').strip()

    hq = VoucherSaleHistory.query.join(Voucher)
    if branch_id:
        hq = hq.filter(Voucher.branch_id == branch_id)
    histories = hq.order_by(VoucherSaleHistory.sold_at.desc(), VoucherSaleHistory.id.desc()).all()

    if date_filter:
        try:
            target_date = datetime.strptime(date_filter, '%Y-%m-%d').date()
            histories = [h for h in histories if h.sold_at and h.sold_at.date() == target_date]
        except ValueError:
            pass

    if search_q:
        histories = [
            h for h in histories
            if search_q in (h.student_name or '').lower()
            or search_q in (h.mobile or '').lower()
            or search_q in (h.voucher.voucher_code if h.voucher else '').lower()
        ]
    if exam_type_filter:
        histories = [h for h in histories if h.voucher and str(h.voucher.exam_type_id) == exam_type_filter]

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        'S.No', 'Date & Time', 'Voucher Code', 'Exam Type', 'Student Name',
        'Mobile', 'Email', 'Selling Price', 'Discount', 'Final Amount',
        'Paid Amount', 'Pending Amount', 'Payment Mode', 'Payment Status', 'Reference', 'Notes'
    ])

    for i, h in enumerate(histories, 1):
        writer.writerow([
            i,
            h.sold_at.strftime('%d-%b-%Y %H:%M') if h.sold_at else '-',
            h.voucher.voucher_code if h.voucher else '-',
            h.voucher.exam_type.name if h.voucher and h.voucher.exam_type else '-',
            h.student_name or '-',
            h.mobile or '-',
            h.email or '-',
            f"{h.selling_price:.2f}",
            f"{h.discount:.2f}",
            f"{h.final_amount:.2f}",
            f"{h.paid_amount:.2f}",
            f"{h.balance_amount:.2f}",
            h.payment_mode or '-',
            h.payment_status or '-',
            h.payment_reference or '-',
            h.notes or '-',
        ])

    filename = f"voucher_sales_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    return Response(
        output.getvalue(),
        mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename={filename}'}
    )


# Standalone sub-routes for direct link compatibility
@vouchers_bp.route('/stock')
def stock():
    return redirect(url_for('vouchers.dashboard', tab='overview', status='Available'))


@vouchers_bp.route('/issued')
def issued():
    return redirect(url_for('vouchers.dashboard', tab='sold'))


@vouchers_bp.route('/purchases')
def purchases():
    return redirect(url_for('vouchers.dashboard', tab='batches'))


@vouchers_bp.route('/students')
def students():
    return redirect(url_for('vouchers.dashboard', tab='students'))


@vouchers_bp.route('/students/<int:student_id>')
def student_detail(student_id):
    student = VoucherStudent.query.get(student_id)
    if not student:
        # Fallback to Candidate
        cand = Candidate.query.get_or_404(student_id)
        vouchers = Voucher.query.filter_by(student_id=cand.id).all()
        return render_template(
            'voucher_student_detail.html',
            student=cand,
            vouchers=vouchers,
            total_amount=sum(v.selling_price or 0 for v in vouchers),
            total_profit=sum(v.profit or 0 for v in vouchers)
        )

    sales = VoucherSaleHistory.query.filter_by(voucher_student_id=student.id).order_by(
        VoucherSaleHistory.sold_at.desc()
    ).all()
    total_amount = sum(float(s.final_amount or 0) for s in sales)
    total_profit = sum(float(s.final_amount or 0) - float(s.voucher.purchase_cost or 0) for s in sales if s.voucher)

    return render_template(
        'voucher_student_detail.html',
        student=student,
        sales=sales,
        total_amount=total_amount,
        total_profit=total_profit
    )
