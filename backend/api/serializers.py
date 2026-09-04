from datetime import datetime

def iso(value):
    if value is None:
        return None
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    return str(value)

def branch_dict(b):
    return {'id': b.id, 'branch_name': b.branch_name, 'address': b.address, 'contact_info': b.contact_info,
            'region': b.region, 'status': b.status, 'created_at': iso(b.created_at), 'updated_at': iso(b.updated_at)}

def exam_type_dict(e):
    return {'id': e.id, 'name': e.name, 'language': e.language, 'description': e.description, 'status': e.status, 'created_at': iso(e.created_at)}

def branch_exam_dict(x):
    return {'id': x.id, 'branch_id': x.branch_id, 'branch_name': x.branch.branch_name if x.branch else None,
            'exam_type_id': x.exam_type_id, 'exam_type_name': x.exam_type.name if x.exam_type else None, 'status': x.status,
            'created_at': iso(x.created_at)}

def session_dict(s):
    be = s.branch_exam
    return {'id': s.id, 'branch_exam_id': s.branch_exam_id, 'branch_id': be.branch_id if be else None,
            'branch_name': be.branch.branch_name if be and be.branch else None,
            'exam_type_id': be.exam_type_id if be else None,
            'exam_type_name': be.exam_type.name if be and be.exam_type else None,
            'exam_date': iso(s.exam_date), 'start_time': s.start_time, 'end_time': s.end_time,
            'fee': s.fee, 'seat_capacity': s.seat_capacity, 'status': s.status,
            'original_date': iso(s.original_date), 'reschedule_reason': s.reschedule_reason,
            'cancellation_reason': s.cancellation_reason}

def team_dict(t):
    return {'id': t.id, 'name': t.name, 'location': t.location, 'phone': t.phone,
            'exam_type_id': t.exam_type_id, 'exam_type_name': t.exam_type.name if t.exam_type else None,
            'status': t.status, 'candidate_count': len(t.candidates or []),
            'created_at': iso(t.created_at), 'updated_at': iso(t.updated_at)}

def candidate_dict(c):
    return {'id': c.id, 'name': c.name, 'email': c.email, 'phone': c.phone, 'register_number': c.register_number,
            'test_type': c.test_type, 'exam_date': c.exam_date, 'status': c.status, 'branch_id': c.branch_id,
            'branch_name': c.branch.branch_name if c.branch else None, 'exam_type_id': c.exam_type_id,
            'exam_type_name': c.exam_type.name if c.exam_type else None, 'team_id': c.team_id,
            'team_name': c.team.name if c.team else None, 'team_location': c.team.location if c.team else None,
            'created_at': iso(c.created_at)}

def attempt_dict(a):
    return {'id': a.id, 'candidate_id': a.candidate_id, 'candidate_name': a.candidate.name if a.candidate else None,
            'exam_type_id': a.exam_type_id, 'exam_type_name': a.exam_type.name if a.exam_type else None,
            'branch_id': a.branch_id, 'branch_name': a.branch.branch_name if a.branch else None,
            'session_id': a.session_id, 'attempt_number': a.attempt_number,
            'original_scheduled_date': a.original_scheduled_date, 'scheduled_date': a.scheduled_date,
            'actual_exam_date': a.actual_exam_date, 'status': a.status, 'result': a.result,
            'was_rescheduled': a.was_rescheduled, 'cancellation_reason': a.cancellation_reason,
            'reschedule_reason': a.reschedule_reason, 'remarks': a.remarks}

def expense_category_dict(c):
    return {'id': c.id, 'name': c.name, 'status': c.status, 'created_at': iso(c.created_at)}

def expense_dict(e):
    return {'id': e.id, 'category': e.category, 'category_id': e.category_id,
            'category_name': e.expense_category.name if e.expense_category else e.category,
            'amount': e.amount, 'employee_id': e.employee_id, 'employee_name': e.employee.full_name if e.employee else None, 'description': e.description, 'note': e.note,
            'date_incurred': iso(e.date_incurred), 'branch_id': e.branch_id,
            'branch_name': e.branch.branch_name if e.branch else None, 'payment_mode': e.payment_mode,
            'receipt_file': e.receipt_file, 'status': e.status, 'created_at': iso(e.created_at), 'updated_at': iso(e.updated_at)}

def voucher_purchase_invoice_dict(inv):
    return {
        'id': inv.id,
        'invoice_number': inv.invoice_number,
        'supplier': inv.supplier,
        'invoice_date': iso(inv.invoice_date),
        'branch_id': inv.branch_id,
        'branch_name': inv.branch.branch_name if inv.branch else None,
        'payment_status': inv.payment_status,
        'payment_mode': inv.payment_mode,
        'payment_reference': inv.payment_reference,
        'subtotal': inv.subtotal or 0,
        'discount': inv.discount or 0,
        'tax': inv.tax or 0,
        'total_amount': inv.total_amount or 0,
        'paid_amount': inv.paid_amount or 0,
        'balance_amount': inv.balance_amount or 0,
        'notes': inv.notes,
        'status': inv.status,
        'created_at': iso(inv.created_at),
        'updated_at': iso(inv.updated_at),
        'items': [
            {
                'id': item.id,
                'exam_type_id': item.exam_type_id,
                'exam_name': item.exam_type.name if item.exam_type else '-',
                'quantity': item.quantity,
                'unit_price': item.unit_price or 0,
                'discount': item.discount or 0,
                'tax': item.tax or 0,
                'total_amount': item.total_amount or 0,
            }
            for item in inv.items
        ],
    }


def budget_dict(b):
    return {'id': b.id, 'branch_id': b.branch_id, 'category_id': b.category_id, 'period_year': b.period_year,
            'period_month': b.period_month, 'budget_amount': b.budget_amount}


def employee_dict(e):
    return {
        'id': e.id, 'employee_id': e.employee_id, 'employee_code': e.employee_id,
        'full_name': e.full_name, 'name': e.full_name, 'designation': e.designation,
        'username': e.credential.username if getattr(e, 'credential', None) else None,
        'branch_id': e.branch_id, 'branch_name': e.branch.branch_name if e.branch else None,
        'contact_number': e.contact_number, 'phone': e.contact_number, 'email': e.email,
        'joining_date': iso(e.joining_date), 'address': e.address,
        'basic_salary': e.basic_salary or 0, 'status': e.status,
        'exit_date': iso(e.exit_date), 'exit_reason': e.exit_reason, 'exit_remarks': e.exit_remarks,
        'created_at': iso(e.created_at), 'updated_at': iso(e.updated_at),
    }

def salary_expense_dict(e):
    return {
        'id': e.id, 'amount': e.amount, 'category': e.category,
        'date_incurred': iso(e.date_incurred), 'payment_mode': e.payment_mode,
        'description': e.description, 'status': e.status,
        'employee_id': e.employee_id, 'employee_name': e.employee.full_name if e.employee else None,
        'branch_id': e.branch_id, 'branch_name': e.branch.branch_name if e.branch else None,
    }
