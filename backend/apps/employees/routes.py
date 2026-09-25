from datetime import datetime, date
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from apps.models import db, Employee, Branch

employees_bp = Blueprint('employees', __name__, url_prefix='/employees')


@employees_bp.route('/')
def list_employees():
    search = (request.args.get('q') or '').strip()
    status_filter = (request.args.get('status') or '').strip()
    branch_filter = (request.args.get('branch_id') or '').strip()

    query = Employee.query

    if search:
        like = f"%{search}%"
        query = query.filter(
            db.or_(
                Employee.full_name.ilike(like),
                Employee.employee_id.ilike(like),
                Employee.designation.ilike(like),
                Employee.contact_number.ilike(like),
                Employee.email.ilike(like)
            )
        )
    if status_filter and status_filter != 'All':
        query = query.filter(Employee.status == status_filter)
    if branch_filter:
        query = query.filter(Employee.branch_id == int(branch_filter))

    active_branch_id = session.get('active_branch_id')
    if active_branch_id and not branch_filter:
        query = query.filter(Employee.branch_id == int(active_branch_id))

    employees = query.order_by(Employee.full_name.asc()).all()
    branches = Branch.query.order_by(Branch.name.asc()).all()

    return render_template(
        'employees.html',
        employees=employees,
        branches=branches,
        search=search,
        status_filter=status_filter,
        branch_filter=branch_filter
    )


@employees_bp.route('/save', methods=['POST'])
def save_employee():
    emp_id_db = request.form.get('id')
    employee_id_code = (request.form.get('employee_id') or '').strip()
    full_name = (request.form.get('full_name') or '').strip()
    designation = (request.form.get('designation') or '').strip()
    branch_id = request.form.get('branch_id')
    contact_number = (request.form.get('contact_number') or '').strip() or None
    email = (request.form.get('email') or '').strip() or None
    joining_date_str = (request.form.get('joining_date') or '').strip()
    basic_salary_str = (request.form.get('basic_salary') or '0').strip()
    address = (request.form.get('address') or '').strip() or None
    status = request.form.get('status') or 'Active'

    next_url = request.form.get('next') or url_for('employees.list_employees')

    if not full_name:
        flash('Full Name is required.', 'error')
        return redirect(next_url)

    if not designation:
        flash('Designation is required.', 'error')
        return redirect(next_url)

    if not branch_id:
        flash('Branch is required.', 'error')
        return redirect(next_url)

    try:
        bid = int(branch_id)
    except ValueError:
        flash('Invalid branch.', 'error')
        return redirect(next_url)

    try:
        joining_date = datetime.strptime(joining_date_str, '%Y-%m-%d').date() if joining_date_str else date.today()
    except ValueError:
        joining_date = date.today()

    try:
        basic_salary = float(basic_salary_str)
    except ValueError:
        basic_salary = 0.0

    if emp_id_db:
        emp = Employee.query.get_or_404(int(emp_id_db))
        emp.full_name = full_name
        emp.designation = designation
        emp.branch_id = bid
        emp.contact_number = contact_number
        emp.email = email
        emp.joining_date = joining_date
        emp.basic_salary = basic_salary
        emp.address = address
        emp.status = status
        db.session.commit()
        flash(f'Employee "{full_name}" updated successfully.', 'success')
    else:
        if not employee_id_code:
            # Auto generate code
            count = Employee.query.count() + 1
            employee_id_code = f"EMP{count:04d}"
        
        # Check uniqueness
        if Employee.query.filter_by(employee_id=employee_id_code).first():
            employee_id_code = f"EMP{Employee.query.count() + 100:04d}"

        emp = Employee(
            employee_id=employee_id_code,
            full_name=full_name,
            designation=designation,
            branch_id=bid,
            contact_number=contact_number,
            email=email,
            joining_date=joining_date,
            basic_salary=basic_salary,
            address=address,
            status=status
        )
        db.session.add(emp)
        db.session.commit()
        flash(f'Employee "{full_name}" created successfully.', 'success')

    return redirect(next_url)


@employees_bp.route('/<int:emp_id>/toggle-status', methods=['POST'])
def toggle_status(emp_id):
    emp = Employee.query.get_or_404(emp_id)
    emp.status = 'Inactive' if emp.status == 'Active' else 'Active'
    db.session.commit()
    flash(f'Employee "{emp.full_name}" status changed to {emp.status}.', 'success')
    return redirect(request.form.get('next') or url_for('employees.list_employees'))
