from datetime import date, datetime
from uuid import uuid4
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from apps.models import db, VoucherBatch, Voucher, Candidate, ExamType, Branch, Expense, ExpenseCategory

vouchers_bp = Blueprint('vouchers', __name__, url_prefix='/vouchers')

STATUSES = ['Available', 'Assigned', 'Used', 'Expired', 'Cancelled']
PAYMENT_STATUSES = ['Pending', 'Partial', 'Paid']

def _branch_id():
    return session.get('active_branch_id')

def _voucher_query():
    q = Voucher.query
    bid = _branch_id()
    if bid:
        q = q.filter(Voucher.branch_id == int(bid))
    return q

def _batch_query():
    q = VoucherBatch.query
    bid = _branch_id()
    if bid:
        q = q.filter(VoucherBatch.branch_id == int(bid))
    return q

def _money(v):
    return float(v or 0)

@vouchers_bp.route('/')
def dashboard():
    q = _voucher_query()
    available = q.filter(Voucher.status == 'Available').count()
    issued_q = q.filter(Voucher.status.in_(['Assigned', 'Used']))
    issued = issued_q.count()
    used = q.filter(Voucher.status == 'Used').count()
    expired = q.filter(Voucher.status == 'Expired').count()
    cancelled = q.filter(Voucher.status == 'Cancelled').count()
    issued_rows = issued_q.all()
    sales = sum(_money(v.selling_price) for v in issued_rows)
    cost = sum(_money(v.purchase_cost) for v in issued_rows)
    profit = sales - cost
    purchased = _batch_query().with_entities(db.func.coalesce(db.func.sum(VoucherBatch.quantity), 0)).scalar() or 0
    purchase_cost = _batch_query().with_entities(db.func.coalesce(db.func.sum(VoucherBatch.total_cost), 0)).scalar() or 0
    return render_template('voucher_dashboard.html', stats={
        'purchased': int(purchased), 'available': available, 'issued': issued,
        'used': used, 'expired': expired, 'cancelled': cancelled,
        'purchase_cost': purchase_cost, 'sales': sales, 'profit': profit,
        'stock_value': available * (purchase_cost / purchased if purchased else 0),
    })

@vouchers_bp.route('/purchase', methods=['GET', 'POST'])
def purchase():
    branches = Branch.query.filter_by(status='Active').order_by(Branch.branch_name).all()
    if request.method == 'POST':
        try:
            quantity = int(request.form.get('quantity') or 0)
            cost = float(request.form.get('cost_per_voucher') or 0)
            selling = float(request.form.get('selling_price') or 0)
        except ValueError:
            quantity, cost, selling = 0, 0, 0
        codes = [x.strip() for x in (request.form.get('voucher_codes') or '').splitlines() if x.strip()]
        if quantity <= 0 or cost <= 0 or selling < 0:
            flash('Quantity and purchase cost must be greater than 0.', 'error')
            return render_template('voucher_purchase.html', branches=branches, form_data=request.form)
        if codes and len(codes) != quantity:
            flash(f'You entered {len(codes)} voucher codes but quantity is {quantity}. Enter exactly one code per line.', 'error')
            return render_template('voucher_purchase.html', branches=branches, form_data=request.form)
        if not codes:
            prefix = (request.form.get('code_prefix') or 'VCH').strip().upper() or 'VCH'
            while len(codes) < quantity:
                code = f'{prefix}-{datetime.now().strftime("%Y%m%d")}-{uuid4().hex[:8].upper()}'
                if not Voucher.query.filter_by(voucher_code=code).first():
                    codes.append(code)
        duplicate = Voucher.query.filter(Voucher.voucher_code.in_(codes)).first()
        if duplicate:
            flash(f'Voucher code already exists: {duplicate.voucher_code}', 'error')
            return render_template('voucher_purchase.html', branches=branches, form_data=request.form)
        bid = request.form.get('branch_id') or (_branch_id() or '')
        branch_id = int(bid) if str(bid).isdigit() else None
        batch_no = f'VB-{datetime.now().strftime("%Y%m%d%H%M%S")}-{uuid4().hex[:4].upper()}'
        batch = VoucherBatch(batch_number=batch_no, supplier=request.form.get('supplier'),
            purchase_date=date.fromisoformat(request.form.get('purchase_date')) if request.form.get('purchase_date') else date.today(),
            quantity=quantity, cost_per_voucher=cost, default_selling_price=selling,
            total_cost=quantity * cost, notes=request.form.get('notes'), branch_id=branch_id)
        db.session.add(batch); db.session.flush()
        # Purchase is recorded in Expense Management under a dedicated category.
        cat = ExpenseCategory.query.filter(db.func.lower(ExpenseCategory.name) == 'exam voucher purchase').first()
        if not cat:
            cat = ExpenseCategory(name='Exam Voucher Purchase', status='Active'); db.session.add(cat); db.session.flush()
        expense = Expense(category=cat.name, category_id=cat.id, amount=quantity * cost,
            description=f'Bulk exam voucher purchase - {batch_no} ({quantity} vouchers)',
            date_incurred=datetime.combine(batch.purchase_date, datetime.min.time()), branch_id=branch_id,
            payment_mode=request.form.get('payment_mode') or 'Other', status='Active')
        db.session.add(expense); db.session.flush(); batch.expense_id = expense.id
        for code in codes:
            db.session.add(Voucher(voucher_code=code, batch_id=batch.id, purchase_cost=cost,
                selling_price=selling, branch_id=branch_id, status='Available'))
        db.session.commit()
        flash(f'{quantity} vouchers purchased successfully. Expense ₹{quantity * cost:,.2f} recorded.', 'success')
        return redirect(url_for('vouchers.dashboard'))
    return render_template('voucher_purchase.html', branches=branches, form_data={})

@vouchers_bp.route('/stock')
def stock():
    status = request.args.get('status', 'Available')
    search = (request.args.get('q') or '').strip()
    q = _voucher_query()
    if status in STATUSES: q = q.filter(Voucher.status == status)
    if search:
        like = f'%{search}%'
        q = q.outerjoin(Candidate, Voucher.student_id == Candidate.id).filter(db.or_(Voucher.voucher_code.ilike(like), Candidate.name.ilike(like)))
    rows = q.order_by(Voucher.created_at.desc()).all()
    return render_template('voucher_list.html', title=f'{status} Vouchers', vouchers=rows, status=status, search=search)

@vouchers_bp.route('/issued')
def issued():
    q = _voucher_query().filter(Voucher.status.in_(['Assigned', 'Used']))
    search = (request.args.get('q') or '').strip()
    if search:
        like=f'%{search}%'; q=q.outerjoin(Candidate, Voucher.student_id == Candidate.id).filter(db.or_(Voucher.voucher_code.ilike(like), Candidate.name.ilike(like), Candidate.register_number.ilike(like)))
    rows=q.order_by(Voucher.issued_at.desc(), Voucher.id.desc()).all()
    return render_template('voucher_list.html', title='Issued Vouchers', vouchers=rows, status='Issued', search=search)

@vouchers_bp.route('/purchases')
def purchases():
    rows = _batch_query().order_by(VoucherBatch.purchase_date.desc(), VoucherBatch.id.desc()).all()
    return render_template('voucher_purchases.html', batches=rows)

@vouchers_bp.route('/students/<int:student_id>')
def student_detail(student_id):
    student = Candidate.query.get_or_404(student_id)
    rows = _voucher_query().filter(Voucher.student_id == student.id, Voucher.status.in_(['Assigned','Used'])).order_by(Voucher.issued_at.desc()).all()
    return render_template('voucher_student_detail.html', student=student, vouchers=rows, total_amount=sum(_money(v.selling_price) for v in rows), total_profit=sum(v.profit for v in rows))

@vouchers_bp.route('/assign', methods=['GET','POST'])
def assign():
    available = _voucher_query().filter(Voucher.status == 'Available').order_by(Voucher.id).all()
    students = Candidate.query.order_by(Candidate.name).all()
    exams = ExamType.query.filter_by(status='Active').order_by(ExamType.name).all()
    if request.method == 'POST':
        voucher = Voucher.query.get_or_404(int(request.form.get('voucher_id')))
        if voucher.status != 'Available':
            flash('This voucher is no longer available.', 'error'); return redirect(url_for('vouchers.assign'))
        student = Candidate.query.get(int(request.form.get('student_id'))) if str(request.form.get('student_id')).isdigit() else None
        if not student:
            flash('Student is required.', 'error'); return redirect(url_for('vouchers.assign'))
        price = float(request.form.get('selling_price') or voucher.selling_price or 0)
        voucher.student_id=student.id; voucher.exam_type_id=int(request.form.get('exam_type_id')) if str(request.form.get('exam_type_id')).isdigit() else None
        voucher.selling_price=price; voucher.status='Assigned'; voucher.issued_at=datetime.utcnow()
        voucher.payment_status=request.form.get('payment_status') or 'Pending'; voucher.payment_mode=request.form.get('payment_mode') or None
        voucher.payment_reference=request.form.get('payment_reference') or None; voucher.notes=request.form.get('notes') or None
        db.session.commit()
        flash(f'Voucher {voucher.voucher_code} assigned to {student.name}. Profit ₹{voucher.profit:,.2f}.', 'success')
        return redirect(url_for('vouchers.issued'))
    return render_template('voucher_assign.html', available=available, students=students, exams=exams)

@vouchers_bp.route('/<int:voucher_id>')
def detail(voucher_id):
    voucher = _voucher_query().filter(Voucher.id == voucher_id).first_or_404()
    return render_template('voucher_detail.html', voucher=voucher)

@vouchers_bp.route('/<int:voucher_id>/use', methods=['POST'])
def use(voucher_id):
    voucher=_voucher_query().filter(Voucher.id==voucher_id).first_or_404()
    if voucher.status != 'Assigned': flash('Only assigned vouchers can be marked as used.', 'error')
    else:
        voucher.status='Used'; voucher.used_at=datetime.utcnow(); db.session.commit(); flash('Voucher marked as used.', 'success')
    return redirect(url_for('vouchers.detail', voucher_id=voucher.id))

@vouchers_bp.route('/<int:voucher_id>/cancel', methods=['POST'])
def cancel(voucher_id):
    voucher=_voucher_query().filter(Voucher.id==voucher_id).first_or_404()
    if voucher.status == 'Used': flash('A used voucher cannot be cancelled.', 'error')
    else:
        voucher.status='Cancelled'; db.session.commit(); flash('Voucher cancelled; stock history preserved.', 'success')
    return redirect(url_for('vouchers.detail', voucher_id=voucher.id))

@vouchers_bp.route('/students')
def students():
    rows=[]
    q=_voucher_query().filter(Voucher.status.in_(['Assigned','Used'])).all()
    by={}
    for v in q:
        if not v.student: continue
        item=by.setdefault(v.student.id, {'student':v.student,'count':0,'amount':0,'profit':0,'used':0})
        item['count']+=1; item['amount']+=_money(v.selling_price); item['profit']+=v.profit; item['used']+=1 if v.status=='Used' else 0
    rows=sorted(by.values(), key=lambda x:x['student'].name.lower())
    return render_template('voucher_students.html', rows=rows)
