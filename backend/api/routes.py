from datetime import datetime
from flask import request, jsonify, g
from flask import current_app
from sqlalchemy import func, or_

from . import api_bp
from .auth import authenticate, issue_tokens, verify_token, api_token_required
from .serializers import *
from apps.models import (db, Branch, ExamType, BranchExam, ExamSession, Candidate, ExamAttempt, ExamTeam,
                         Expense, ExpenseCategory, ExpenseBudget, Voucher, SessionCandidate, Employee, EmployeeCredential)


def ok(data=None, message=None, status=200):
    payload = {'success': True}
    if data is not None: payload['data'] = data
    if message: payload['message'] = message
    return jsonify(payload), status

def fail(message, status=400, errors=None):
    payload = {'success': False, 'message': message}
    if errors: payload['errors'] = errors
    return jsonify(payload), status

def body():
    return request.get_json(silent=True) or {}


def _employee_branch_id():
    """Return the authenticated employee's assigned branch, if applicable."""
    if g.api_identity.get('role') != 'Employee':
        return None
    try:
        employee_id = int(g.api_identity.get('employee_id') or g.api_identity.get('sub'))
    except (TypeError, ValueError):
        return None
    employee = Employee.query.get(employee_id)
    return employee.branch_id if employee else None


def _employee_branch_required(requested_branch_id=None):
    """Resolve branch for employee requests; never allow another branch."""
    own_branch_id = _employee_branch_id()
    if own_branch_id is None:
        return requested_branch_id
    if requested_branch_id is not None and int(requested_branch_id) != int(own_branch_id):
        return None
    return own_branch_id

@api_bp.post('/auth/login/')
def login():
    data = body()
    identity = authenticate(data.get('username'), data.get('password'))
    if not identity: return fail('Invalid username or password.', 401)
    tokens = issue_tokens(identity, current_app.config['SECRET_KEY'])
    return ok({'tokens': tokens, 'user': identity})

@api_bp.post('/auth/refresh/')
def refresh():
    token = request.headers.get('Authorization', '')[7:].strip() if request.headers.get('Authorization', '').startswith('Bearer ') else ''
    data = verify_token(token, current_app.config['SECRET_KEY'], 'refresh', 7 * 24 * 60 * 60)
    if not data: return fail('Invalid or expired refresh token.', 401)
    identity = {
        'id': data['sub'],
        'username': data.get('username', data['sub']),
        'role': data.get('role', 'Admin'),
        'employee_id': int(data['sub']) if data.get('role') == 'Employee' and str(data.get('sub')).isdigit() else None,
    }
    tokens = issue_tokens(identity, current_app.config['SECRET_KEY'])
    return ok({'access': tokens['access']})

@api_bp.get('/auth/me/')
@api_token_required
def me():
    identity = g.api_identity
    return ok({
        'id': identity['sub'],
        'username': identity.get('username', identity['sub']),
        'role': identity.get('role', 'Admin'),
        'employee_id': identity.get('employee_id') or (int(identity['sub']) if identity.get('role') == 'Employee' and str(identity.get('sub')).isdigit() else None),
    })

@api_bp.get('/dashboard/')
@api_token_required
def dashboard():
    """Mobile dashboard data with live real-time candidate and branch statistics."""
    from collections import defaultdict
    from datetime import date, timedelta

    branch_id = _employee_branch_required(request.args.get('branch_id', type=int))
    if g.api_identity.get('role') == 'Employee' and branch_id is None:
        return fail('Employee is not assigned to a branch.', 403)
    today = date.today()
    tomorrow = today + timedelta(days=1)
    today_str = today.strftime('%Y-%m-%d')
    tomorrow_str = tomorrow.strftime('%Y-%m-%d')

    attempts_q = ExamAttempt.query
    candidates_q = Candidate.query
    branches_q = Branch.query

    if branch_id:
        attempts_q = attempts_q.filter(ExamAttempt.branch_id == branch_id)
        candidates_q = candidates_q.filter(Candidate.branch_id == branch_id)
        branches_q = branches_q.filter(Branch.id == branch_id)

    attempts = attempts_q.all()
    all_candidates = candidates_q.all()
    branches = branches_q.order_by(Branch.branch_name.asc()).all()

    today_candidates_by_branch = defaultdict(set)
    tomorrow_candidates_by_branch = defaultdict(set)
    today_exam_groups = {}

    # 1. Process attempts
    for a in attempts:
        if a.status == 'Cancelled':
            continue
        d = a.actual_exam_date if a.status == 'Completed' and a.actual_exam_date else a.scheduled_date
        if d == today_str:
            today_candidates_by_branch[a.branch_id].add(a.candidate_id)
            key = (a.branch_id, a.exam_type_id, a.scheduled_date, a.session.start_time if a.session else '09:00')
            group = today_exam_groups.setdefault(key, {
                'branch_id': a.branch_id,
                'branch_name': a.branch.branch_name if a.branch else '-',
                'exam_type_id': a.exam_type_id,
                'exam_type_name': a.exam_type.name if a.exam_type else '-',
                'date': d,
                'start_time': a.session.start_time if a.session else '09:00',
                'end_time': a.session.end_time if a.session else '12:00',
                'candidate_ids': set(),
                'status': 'Completed' if a.status == 'Completed' else 'Scheduled',
            })
            group['candidate_ids'].add(a.candidate_id)
            if a.status == 'Scheduled':
                group['status'] = 'Scheduled'
        elif a.scheduled_date == tomorrow_str:
            tomorrow_candidates_by_branch[a.branch_id].add(a.candidate_id)

    # 2. Process all candidates directly (in case attempt was not yet created)
    for c in all_candidates:
        if c.status == 'Cancelled':
            continue
        if c.exam_date == today_str:
            today_candidates_by_branch[c.branch_id].add(c.id)
            key = (c.branch_id, c.exam_type_id, c.exam_date, '09:00')
            group = today_exam_groups.setdefault(key, {
                'branch_id': c.branch_id,
                'branch_name': c.branch.branch_name if c.branch else (c.test_type or '-'),
                'exam_type_id': c.exam_type_id,
                'exam_type_name': c.exam_type.name if c.exam_type else (c.test_type or '-'),
                'date': c.exam_date,
                'start_time': '09:00',
                'end_time': '12:00',
                'candidate_ids': set(),
                'status': c.status or 'Scheduled',
            })
            group['candidate_ids'].add(c.id)
        elif c.exam_date == tomorrow_str:
            tomorrow_candidates_by_branch[c.branch_id].add(c.id)

    # Build branch overview with live counts (only branches with candidates today or tomorrow)
    branch_overview = []
    for b in branches:
        today_count = len(today_candidates_by_branch.get(b.id, set()))
        tomorrow_count = len(tomorrow_candidates_by_branch.get(b.id, set()))
        branch_exams_count = sum(1 for g in today_exam_groups.values() if g['branch_id'] == b.id)
        if today_count > 0 or tomorrow_count > 0:
            branch_overview.append({
                'id': b.id,
                'name': b.branch_name,
                'status': b.status,
                'today_exams': branch_exams_count,
                'today_candidates': today_count,
                'tomorrow_candidates': tomorrow_count,
                'total_scheduled': today_count + tomorrow_count,
            })
    branch_overview.sort(key=lambda x: (-x['today_candidates'], -x['tomorrow_candidates'], x['name'].lower()))

    today_exams = []
    for group in today_exam_groups.values():
        today_exams.append({
            'branch_id': group['branch_id'],
            'branch_name': group['branch_name'],
            'exam_type_id': group['exam_type_id'],
            'exam_type_name': group['exam_type_name'],
            'date': group['date'],
            'start_time': group['start_time'],
            'end_time': group['end_time'],
            'candidate_count': len(group['candidate_ids']),
            'status': group['status'],
        })
    today_exams.sort(key=lambda x: (x['start_time'], x['branch_name'].lower(), x['exam_type_name'].lower()))

    tomorrow_candidates = []
    for b in branches:
        ids = tomorrow_candidates_by_branch.get(b.id, set())
        if ids:
            exam_counts = defaultdict(int)
            for c in all_candidates:
                if c.status != 'Cancelled' and c.exam_date == tomorrow_str and c.branch_id == b.id:
                    exam_counts[c.exam_type.name if c.exam_type else (c.test_type or 'General')] += 1
            for a in attempts:
                if a.status != 'Cancelled' and a.scheduled_date == tomorrow_str and a.branch_id == b.id:
                    exam_counts[a.exam_type.name if a.exam_type else 'General'] += 1
            tomorrow_candidates.append({
                'branch_id': b.id,
                'branch_name': b.branch_name,
                'candidate_count': len(ids),
                'exam_breakdown': dict(sorted(exam_counts.items())),
            })
    tomorrow_candidates.sort(key=lambda x: (-x['candidate_count'], x['branch_name'].lower()))

    total_unique_candidates = len(all_candidates)

    stats = {
        'total_branches': branches_q.count(),
        'today_exams': len(today_exams),
        'today_candidates': len(set().union(*today_candidates_by_branch.values())) if today_candidates_by_branch else 0,
        'tomorrow_candidates': sum(x['candidate_count'] for x in tomorrow_candidates),
        'total_attended_candidates': total_unique_candidates,
        'today': today_str,
        'tomorrow': tomorrow_str,
    }
    return ok({
        'stats': stats,
        'branch_overview': branch_overview,
        'today_exams': today_exams,
        'tomorrow_candidates': tomorrow_candidates,
        'branch_id': branch_id,
    })

@api_bp.get('/exams/attended-history/')
@api_token_required
def attended_history():
    """Completed/attended exam history with day/date/month/range filters."""
    q = (ExamAttempt.query
         .join(Candidate, ExamAttempt.candidate_id == Candidate.id)
         .join(ExamType, ExamAttempt.exam_type_id == ExamType.id)
         .join(Branch, ExamAttempt.branch_id == Branch.id)
         .filter(ExamAttempt.status == 'Completed'))

    branch_id = _employee_branch_required(request.args.get('branch_id', type=int))
    if g.api_identity.get('role') == 'Employee' and branch_id is None:
        return fail('Employees can only access their assigned branch.', 403)
    exam_type_id = request.args.get('exam_type_id', type=int)
    date_value = (request.args.get('date') or '').strip()
    month_value = (request.args.get('month') or '').strip()  # YYYY-MM
    date_from = (request.args.get('date_from') or '').strip()
    date_to = (request.args.get('date_to') or '').strip()
    search = (request.args.get('q') or '').strip()

    if branch_id:
        q = q.filter(ExamAttempt.branch_id == branch_id)
    if exam_type_id:
        q = q.filter(ExamAttempt.exam_type_id == exam_type_id)
    if search:
        like = f'%{search}%'
        q = q.filter(or_(Candidate.name.ilike(like), Candidate.register_number.ilike(like)))

    # actual_exam_date is stored as YYYY-MM-DD. Older completed records may
    # not have it, so include their scheduled_date as the fallback.
    effective_date = func.coalesce(ExamAttempt.actual_exam_date, ExamAttempt.scheduled_date)
    if date_value:
        q = q.filter(effective_date == date_value)
    elif month_value:
        q = q.filter(effective_date.ilike(f'{month_value}-%'))
    else:
        if date_from:
            q = q.filter(effective_date >= date_from)
        if date_to:
            q = q.filter(effective_date <= date_to)

    rows = q.order_by(effective_date.desc(), ExamAttempt.id.desc()).all()
    data = []
    for a in rows:
        attended_date = a.actual_exam_date or a.scheduled_date
        data.append({
            'attempt_id': a.id,
            'candidate_id': a.candidate_id,
            'candidate_name': a.candidate.name if a.candidate else '-',
            'register_number': a.candidate.register_number if a.candidate else '-',
            'exam_type_name': a.exam_type.name if a.exam_type else '-',
            'branch_name': a.branch.name if a.branch else '-',
            'attended_date': attended_date,
            'attempt_number': a.attempt_number,
            'result': a.result,
            'remarks': a.remarks,
        })

    return ok({'count': len(data), 'rows': data, 'filters': {
        'date': date_value or None,
        'month': month_value or None,
        'date_from': date_from or None,
        'date_to': date_to or None,
        'branch_id': branch_id,
        'exam_type_id': exam_type_id,
    }})

# Branches
@api_bp.get('/branches/')
@api_token_required
def branches():
    q = (request.args.get('q') or '').strip(); status = request.args.get('status')
    query = Branch.query
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None:
        query = query.filter(Branch.id == own_branch_id)
    if q: query = query.filter(or_(Branch.branch_name.ilike(f'%{q}%'), Branch.region.ilike(f'%{q}%'), Branch.address.ilike(f'%{q}%')))
    if status in ('Active','Inactive'): query = query.filter_by(status=status)
    return ok([branch_dict(x) for x in query.order_by(Branch.branch_name.asc()).all()])

@api_bp.post('/branches/')
@api_token_required
def branch_create():
    if g.api_identity.get('role') != 'Admin':
        return fail('Only administrators can manage branches.', 403)
    d = body(); name = (d.get('branch_name') or d.get('name') or '').strip()
    if not name: return fail('Branch name is required.', 422)
    if Branch.query.filter(func.lower(Branch.branch_name) == name.lower()).first(): return fail('Branch already exists.', 409)
    b = Branch(branch_name=name, address=d.get('address'), contact_info=d.get('contact_info'), region=d.get('region'), status=d.get('status') or 'Active')
    db.session.add(b); db.session.commit(); return ok(branch_dict(b), 'Branch created.', 201)

@api_bp.get('/branches/<int:branch_id>/')
@api_token_required
def branch_get(branch_id):
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and branch_id != own_branch_id:
        return fail('Employees can only access their assigned branch.', 403)
    b = Branch.query.get_or_404(branch_id); return ok(branch_dict(b))

@api_bp.put('/branches/<int:branch_id>/')
@api_token_required
def branch_update(branch_id):
    if g.api_identity.get('role') != 'Admin':
        return fail('Only administrators can manage branches.', 403)
    b = Branch.query.get_or_404(branch_id); d = body()
    if 'branch_name' in d or 'name' in d: b.branch_name = (d.get('branch_name') or d.get('name') or '').strip()
    for f in ('address','contact_info','region','status'):
        if f in d: setattr(b, f, d[f])
    if not b.branch_name: return fail('Branch name is required.', 422)
    db.session.commit(); return ok(branch_dict(b), 'Branch updated.')

@api_bp.delete('/branches/<int:branch_id>/')
@api_token_required
def branch_delete(branch_id):
    if g.api_identity.get('role') != 'Admin':
        return fail('Only administrators can manage branches.', 403)
    b = Branch.query.get_or_404(branch_id)
    try:
        BranchExam.query.filter_by(branch_id=branch_id).delete()
        Candidate.query.filter_by(branch_id=branch_id).delete()
        ExamAttempt.query.filter_by(branch_id=branch_id).delete()
        db.session.delete(b)
        db.session.commit()
        return ok(message='Branch deleted successfully.')
    except Exception:
        db.session.rollback()
        b.status = 'Inactive'
        db.session.commit()
        return ok(message='Branch deleted.')

@api_bp.patch('/branches/<int:branch_id>/status/')
@api_bp.patch('/branches/<int:branch_id>/')
@api_token_required
def branch_patch_status(branch_id):
    if g.api_identity.get('role') != 'Admin':
        return fail('Only administrators can manage branches.', 403)
    b = Branch.query.get_or_404(branch_id)
    d = body()
    if 'status' in d and d['status']:
        b.status = d['status']
    elif b.status.lower() == 'active':
        b.status = 'Inactive'
    else:
        b.status = 'Active'
    db.session.commit()
    return ok(branch_dict(b), f'Branch status updated to {b.status}.')

# Exams
@api_bp.get('/exams/types/')
@api_token_required
def exam_types():
    return ok([exam_type_dict(x) for x in ExamType.query.order_by(ExamType.name.asc()).all()])

@api_bp.post('/exams/types/')
@api_token_required
def exam_type_create():
    d=body(); name=(d.get('name') or '').strip(); language=(d.get('language') or '').strip()
    if not name or not language: return fail('Name and language are required.',422)
    x=ExamType(name=name,language=language,description=d.get('description'),status=d.get('status') or 'Active'); db.session.add(x); db.session.commit(); return ok(exam_type_dict(x),'Exam type created.',201)

@api_bp.get('/exams/branch-mappings/')
@api_token_required
def branch_mappings():
    q=BranchExam.query
    branch_id=_employee_branch_required(request.args.get('branch_id',type=int))
    if g.api_identity.get('role') == 'Employee' and branch_id is None:
        return fail('Employees can only access their assigned branch.', 403)
    if branch_id: q=q.filter_by(branch_id=branch_id)
    return ok([branch_exam_dict(x) for x in q.order_by(BranchExam.id.desc()).all()])

@api_bp.post('/exams/branch-mappings/')
@api_token_required
def branch_mapping_create():
    d=body(); bid=d.get('branch_id'); eid=d.get('exam_type_id')
    if not bid or not eid: return fail('branch_id and exam_type_id are required.',422)
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and int(bid) != int(own_branch_id):
        return fail('Employees can only use their assigned branch.', 403)
    if not Branch.query.get(int(bid)) or not ExamType.query.get(int(eid)): return fail('Branch or exam type not found.',404)
    if BranchExam.query.filter_by(branch_id=int(bid),exam_type_id=int(eid)).first(): return fail('Mapping already exists.',409)
    x=BranchExam(branch_id=int(bid),exam_type_id=int(eid),status=d.get('status') or 'Active'); db.session.add(x); db.session.commit(); return ok(branch_exam_dict(x),'Mapping created.',201)

@api_bp.get('/exams/sessions/')
@api_token_required
def exam_sessions():
    q=ExamSession.query
    bid=_employee_branch_required(request.args.get('branch_id',type=int)); status=request.args.get('status')
    if g.api_identity.get('role') == 'Employee' and bid is None:
        return fail('Employees can only access their assigned branch.', 403)
    if bid: q=q.join(BranchExam).filter(BranchExam.branch_id==bid)
    if status: q=q.filter(ExamSession.status==status)
    return ok([session_dict(x) for x in q.order_by(ExamSession.exam_date.asc()).all()])

@api_bp.post('/exams/sessions/')
@api_token_required
def exam_session_create():
    d=body(); required=['branch_exam_id','exam_date','start_time','end_time']
    missing=[x for x in required if not d.get(x)]
    if missing: return fail('Required fields are missing.',422,missing)
    try: exam_date=datetime.strptime(str(d['exam_date']),'%Y-%m-%d').date()
    except ValueError: return fail('exam_date must be YYYY-MM-DD.',422)
    mapping = BranchExam.query.get(int(d['branch_exam_id']))
    if not mapping: return fail('Branch exam mapping not found.',404)
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and mapping.branch_id != own_branch_id:
        return fail('Employees can only create sessions for their assigned branch.', 403)
    s=ExamSession(branch_exam_id=int(d['branch_exam_id']),exam_date=exam_date,start_time=d['start_time'],end_time=d['end_time'],fee=float(d.get('fee') or 0),seat_capacity=int(d.get('seat_capacity') or 0),status=d.get('status') or 'Scheduled')
    db.session.add(s); db.session.commit(); return ok(session_dict(s),'Session created.',201)

@api_bp.get('/exams/teams/')
@api_token_required
def exam_teams():
    q = ExamTeam.query
    exam_type_id = request.args.get('exam_type_id', type=int)
    status = (request.args.get('status') or '').strip()
    term = (request.args.get('q') or '').strip()
    if exam_type_id:
        q = q.filter(ExamTeam.exam_type_id == exam_type_id)
    if status and status != 'All':
        q = q.filter(ExamTeam.status == status)
    if term:
        like = f'%{term}%'
        q = q.filter(or_(ExamTeam.name.ilike(like), ExamTeam.location.ilike(like), ExamTeam.phone.ilike(like)))
    return ok([team_dict(x) for x in q.order_by(ExamTeam.name.asc()).all()])

@api_bp.post('/exams/teams/')
@api_token_required
def exam_team_create():
    d = body()
    name = (d.get('name') or '').strip()
    if not name:
        return fail('Team name is required.', 422)
    exam_type_id = d.get('exam_type_id')
    if exam_type_id and not ExamType.query.get(int(exam_type_id)):
        return fail('Exam type not found.', 404)
    t = ExamTeam(name=name, location=(d.get('location') or '').strip() or None,
                 phone=(d.get('phone') or '').strip() or None,
                 exam_type_id=int(exam_type_id) if exam_type_id else None,
                 status=d.get('status') or 'Active')
    db.session.add(t)
    db.session.commit()
    return ok(team_dict(t), 'Team created.', 201)

@api_bp.put('/exams/teams/<int:team_id>/')
@api_token_required
def exam_team_update(team_id):
    t = ExamTeam.query.get_or_404(team_id)
    d = body()
    if 'name' in d:
        name = (d.get('name') or '').strip()
        if not name:
            return fail('Team name is required.', 422)
        t.name = name
    if 'location' in d: t.location = (d.get('location') or '').strip() or None
    if 'phone' in d: t.phone = (d.get('phone') or '').strip() or None
    if 'exam_type_id' in d:
        eid = d.get('exam_type_id')
        if eid and not ExamType.query.get(int(eid)):
            return fail('Exam type not found.', 404)
        t.exam_type_id = int(eid) if eid else None
    if 'status' in d and d.get('status'): t.status = d.get('status')
    db.session.commit()
    return ok(team_dict(t), 'Team updated.')

@api_bp.delete('/exams/teams/<int:team_id>/')
@api_token_required
def exam_team_delete(team_id):
    t = ExamTeam.query.get_or_404(team_id)
    if Candidate.query.filter(Candidate.team_id == team_id).first():
        return fail('Team cannot be deleted because candidates are assigned to it. Deactivate the team instead.', 409)
    db.session.delete(t)
    db.session.commit()
    return ok(message='Team deleted.')

@api_bp.get('/exams/teams/<int:team_id>/report/')
@api_token_required
def exam_team_report(team_id):
    t = ExamTeam.query.get_or_404(team_id)
    rows = Candidate.query.filter(Candidate.team_id == team_id).order_by(Candidate.exam_date.desc(), Candidate.name.asc()).all()
    return ok({
        'team': team_dict(t),
        'candidates': [candidate_dict(c) for c in rows],
        'candidate_count': len(rows),
    })

@api_bp.get('/exams/candidates/')
@api_token_required
def candidates():
    q=Candidate.query; term=(request.args.get('q') or '').strip(); bid=_employee_branch_required(request.args.get('branch_id',type=int))
    if g.api_identity.get('role') == 'Employee' and bid is None:
        return fail('Employees can only access their assigned branch.', 403)
    if term: q=q.filter(or_(Candidate.name.ilike(f'%{term}%'),Candidate.email.ilike(f'%{term}%'),Candidate.register_number.ilike(f'%{term}%')))
    if bid: q=q.filter(Candidate.branch_id==bid)
    team_id=request.args.get('team_id',type=int)
    if team_id: q=q.filter(Candidate.team_id==team_id)
    return ok([candidate_dict(x) for x in q.order_by(Candidate.created_at.desc()).all()])

@api_bp.post('/exams/candidates/')
@api_token_required
def candidate_create():
    d = body()
    name = (d.get('name') or '').strip()
    if not name:
        return fail('Candidate name is required.', 422)
    own_branch_id = _employee_branch_id()
    requested_branch_id = d.get('branch_id')
    if own_branch_id is not None:
        if requested_branch_id in (None, '') or int(requested_branch_id) != int(own_branch_id):
            return fail('Employees can only add candidates to their assigned branch.', 403)
        d['branch_id'] = own_branch_id
    c = Candidate(
        name=name,
        email=(d.get('email') or '').strip() or None,
        phone=(d.get('phone') or '').strip() or None,
        register_number=(d.get('register_number') or '').strip() or None,
        branch_id=d.get('branch_id'),
        exam_type_id=d.get('exam_type_id'),
        team_id=d.get('team_id'),
        exam_date=d.get('exam_date'),
        status=d.get('status') or 'Registered',
    )
    if c.team_id:
        team = ExamTeam.query.get(int(c.team_id))
        if not team:
            return fail('Team not found.', 404)
        if team.status != 'Active':
            return fail('Selected team is inactive.', 422)
        if team.exam_type_id and c.exam_type_id and team.exam_type_id != int(c.exam_type_id):
            return fail('Selected team is not assigned to this exam type.', 422)
    if c.exam_type_id:
        et = ExamType.query.get(int(c.exam_type_id))
        if et:
            c.test_type = et.name
    db.session.add(c)
    db.session.commit()

    # Automatically create ExamAttempt so dashboard & attempts calendar track it immediately
    try:
        if c.exam_date and c.branch_id and c.exam_type_id:
            attempt_status = {
                'Completed': 'Completed',
                'Absent': 'No Show',
                'Rescheduled': 'Scheduled',
                'Registered': 'Scheduled',
            }.get(c.status or 'Registered', 'Scheduled')
            attempt = ExamAttempt(
                candidate_id=c.id,
                branch_id=c.branch_id,
                exam_type_id=c.exam_type_id,
                scheduled_date=str(c.exam_date),
                original_scheduled_date=str(c.exam_date),
                status=attempt_status,
                actual_exam_date=str(c.exam_date) if attempt_status == 'Completed' else None,
                attempt_number=1,
            )
            db.session.add(attempt)
            db.session.commit()
    except Exception:
        db.session.rollback()

    return ok(candidate_dict(c), 'Candidate created.', 201)

@api_bp.patch('/exams/candidates/<int:candidate_id>/')
@api_token_required
def candidate_update(candidate_id):
    c = Candidate.query.get(candidate_id)
    if not c:
        return fail('Candidate not found.', 404)
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and c.branch_id != own_branch_id:
        return fail('Employees can only access candidates in their assigned branch.', 403)

    d = body()
    status = str(d.get('status') or '').strip()
    allowed = {'Registered', 'Absent', 'Rescheduled', 'Completed'}
    if status not in allowed:
        return fail('Status must be Registered, Absent, Rescheduled, or Completed.', 422)

    c.status = status
    # Keep the candidate master status and its first attempt in sync.
    attempt = (ExamAttempt.query.filter_by(candidate_id=c.id)
               .order_by(ExamAttempt.attempt_number.asc()).first())
    if attempt:
        if status == 'Completed':
            attempt.status = 'Completed'
            attempt.actual_exam_date = attempt.actual_exam_date or attempt.scheduled_date or c.exam_date
        elif status == 'Absent':
            attempt.status = 'No Show'
        elif status == 'Rescheduled':
            # Preserve the existing scheduled date; the dedicated reschedule
            # workflow can move it when a new date is supplied.
            attempt.status = 'Scheduled'
        else:  # Registered
            attempt.status = 'Scheduled'
        db.session.add(attempt)
    db.session.commit()
    return ok(candidate_dict(c), 'Candidate status updated.')

@api_bp.delete('/exams/candidates/<int:candidate_id>/')
@api_token_required
def candidate_delete(candidate_id):
    c = Candidate.query.get(candidate_id)
    if not c:
        return fail('Candidate not found.', 404)
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and c.branch_id != own_branch_id:
        return fail('Employees can only access candidates in their assigned branch.', 403)

    # Candidate has no delete cascade on attempts/session links, so remove
    # dependent rows explicitly before deleting the master candidate.
    SessionCandidate.query.filter_by(candidate_id=candidate_id).delete(synchronize_session=False)
    ExamAttempt.query.filter_by(candidate_id=candidate_id).delete(synchronize_session=False)
    # Vouchers may keep a nullable reference to a candidate; preserve the
    # voucher record while clearing that optional student link.
    Voucher.query.filter_by(student_id=candidate_id).update({'student_id': None}, synchronize_session=False)
    db.session.delete(c)
    db.session.commit()
    return ok(message='Candidate deleted successfully.')

@api_bp.get('/exams/attempts/')
@api_token_required
def attempts():
    q=ExamAttempt.query; bid=_employee_branch_required(request.args.get('branch_id',type=int)); status=request.args.get('status')
    if g.api_identity.get('role') == 'Employee' and bid is None:
        return fail('Employees can only access their assigned branch.', 403)
    if bid: q=q.filter(ExamAttempt.branch_id==bid)
    if status: q=q.filter(ExamAttempt.status==status)
    return ok([attempt_dict(x) for x in q.order_by(ExamAttempt.scheduled_date.desc()).all()])

@api_bp.get('/exams/dashboard/')
@api_token_required
def exam_dashboard():
    bid=_employee_branch_required(request.args.get('branch_id',type=int)); q=ExamAttempt.query
    if g.api_identity.get('role') == 'Employee' and bid is None:
        return fail('Employees can only access their assigned branch.', 403)
    if bid:q=q.filter(ExamAttempt.branch_id==bid)
    rows=q.all()
    return ok({'scheduled':sum(a.status=='Scheduled' for a in rows),'completed':sum(a.status=='Completed' for a in rows),'cancelled':sum(a.status=='Cancelled' for a in rows),'pass':sum(a.result=='Pass' for a in rows),'fail':sum(a.result=='Fail' for a in rows),'pending':sum(a.result=='Pending' for a in rows)})

# Expenses
def _is_salary_expense(expense):
    category = (expense.category or '').strip().lower()
    return expense.employee_id is not None or 'salary' in category or 'payroll' in category


def _employee_can_access_expense(expense):
    if g.api_identity.get('role') != 'Employee':
        return True
    # Employee users must never see or modify employee-linked salary/payroll records.
    return not _is_salary_expense(expense)


# Expenses
@api_bp.get('/expenses/')
@api_token_required
def expenses():
    q = Expense.query
    if g.api_identity.get('role') == 'Employee':
        # Hide employee-linked salary/payroll expenses from the normal expense list.
        q = q.filter(Expense.employee_id.is_(None)).filter(
            ~func.lower(func.coalesce(Expense.category, '')).like('%salary%'),
            ~func.lower(func.coalesce(Expense.category, '')).like('%payroll%')
        )
    bid = _employee_branch_required(request.args.get('branch_id', type=int))
    if g.api_identity.get('role') == 'Employee' and bid is None:
        return fail('Employees can only access their assigned branch.', 403)
    cid = request.args.get('category_id', type=int)
    status = request.args.get('status')
    payment_mode = (request.args.get('payment_mode') or '').strip()
    term = (request.args.get('q') or '').strip()
    date_from = (request.args.get('date_from') or '').strip()
    date_to = (request.args.get('date_to') or '').strip()

    if bid:
        q = q.filter(Expense.branch_id == bid)
    if cid:
        q = q.filter(Expense.category_id == cid)
    if status in ('Active', 'Cancelled'):
        q = q.filter(Expense.status == status)
    if payment_mode and payment_mode != 'All' and payment_mode != 'All Payment Modes':
        q = q.filter(Expense.payment_mode == payment_mode)
    if term:
        like = f'%{term}%'
        q = q.filter(or_(
            Expense.category.ilike(like),
            Expense.description.ilike(like),
            Expense.payment_mode.ilike(like)
        ))
    if date_from:
        try:
            d_from = datetime.fromisoformat(date_from).date() if 'T' in date_from else datetime.strptime(date_from, '%Y-%m-%d').date()
            q = q.filter(Expense.date_incurred >= datetime(d_from.year, d_from.month, d_from.day))
        except Exception:
            pass
    if date_to:
        try:
            d_to = datetime.fromisoformat(date_to).date() if 'T' in date_to else datetime.strptime(date_to, '%Y-%m-%d').date()
            q = q.filter(Expense.date_incurred <= datetime(d_to.year, d_to.month, d_to.day, 23, 59, 59))
        except Exception:
            pass

    return ok([expense_dict(x) for x in q.order_by(Expense.date_incurred.desc()).all()])

@api_bp.post('/expenses/')
@api_token_required
def expense_create():
    d = body()
    if g.api_identity.get('role') == 'Employee':
        requested_category = (d.get('category') or '').strip().lower()
        if d.get('employee_id') not in (None, '') or 'salary' in requested_category or 'payroll' in requested_category:
            return fail('Employees cannot add or manage salary records.', 403)
    amount = d.get('amount')
    try:
        amount = float(amount)
    except (TypeError, ValueError):
        return fail('Valid amount is required.', 422)
    if amount < 0:
        return fail('Amount cannot be negative.', 422)
    category_id = d.get('category_id')
    category = ExpenseCategory.query.get(int(category_id)) if category_id else None
    cat_name = category.name if category else (d.get('category') or 'Other')
    date_val = d.get('date_incurred')
    try:
        date_val = datetime.fromisoformat(str(date_val)).replace(tzinfo=None) if date_val else datetime.utcnow()
    except ValueError:
        try:
            date_val = datetime.strptime(str(date_val), '%Y-%m-%d')
        except Exception:
            return fail('date_incurred must be ISO date/datetime or YYYY-MM-DD.', 422)
    branch_id = d.get('branch_id')
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None:
        if branch_id in (None, '') or int(branch_id) != int(own_branch_id):
            return fail('Employees can only add expenses to their assigned branch.', 403)
        branch_id = own_branch_id
    try:
        branch_id = int(branch_id) if branch_id is not None else None
    except (TypeError, ValueError):
        return fail('Valid branch_id is required.', 422)
    if not branch_id or not Branch.query.get(branch_id):
        return fail('Branch not found.', 404)
    employee_id = d.get('employee_id')
    if employee_id is not None and str(employee_id).strip() != '':
        try: employee_id = int(employee_id)
        except (TypeError, ValueError): return fail('Invalid employee_id.', 422)
        emp = Employee.query.get(employee_id)
        if not emp or emp.branch_id != branch_id:
            return fail('Employee does not belong to the selected branch.', 403)
    else:
        employee_id = None
    e = Expense(
        category=cat_name, category_id=category.id if category else None, amount=amount,
        description=d.get('description') or d.get('note'), date_incurred=date_val,
        branch_id=branch_id, employee_id=employee_id, payment_mode=d.get('payment_mode') or 'Cash',
        status=d.get('status') or 'Active'
    )
    db.session.add(e)
    db.session.commit()
    return ok(expense_dict(e), 'Expense created.', 201)

@api_bp.get('/expenses/<int:expense_id>/')
@api_token_required
def expense_get(expense_id):
    e = Expense.query.get_or_404(expense_id)
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and e.branch_id != own_branch_id:
        return fail('Employees can only access expenses in their assigned branch.', 403)
    if not _employee_can_access_expense(e):
        return fail('Employees cannot access salary records.', 403)
    return ok(expense_dict(e))

@api_bp.put('/expenses/<int:expense_id>/')
@api_bp.patch('/expenses/<int:expense_id>/')
@api_token_required
def expense_update(expense_id):
    e = Expense.query.get_or_404(expense_id)
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and e.branch_id != own_branch_id:
        return fail('Employees can only access expenses in their assigned branch.', 403)
    if not _employee_can_access_expense(e):
        return fail('Employees cannot update salary records.', 403)
    d = body()
    if g.api_identity.get('role') == 'Employee':
        requested_category = (d.get('category') or '').strip().lower()
        if d.get('employee_id') not in (None, '') or 'salary' in requested_category or 'payroll' in requested_category:
            return fail('Employees cannot add or manage salary records.', 403)
    if 'amount' in d and d['amount'] is not None:
        try:
            e.amount = float(d['amount'])
        except (ValueError, TypeError):
            return fail('Valid amount is required.', 422)
    if 'category_id' in d and d['category_id']:
        cat = ExpenseCategory.query.get(int(d['category_id']))
        if cat:
            e.category_id = cat.id
            e.category = cat.name
    elif 'category' in d and d['category']:
        e.category = str(d['category']).strip()
    if 'description' in d or 'note' in d:
        e.description = d.get('description') or d.get('note')
    if 'branch_id' in d and d['branch_id'] is not None and int(d['branch_id']) != e.branch_id:
        return fail('Expense branch cannot be changed.', 403)
    if 'employee_id' in d:
        eid = d.get('employee_id')
        if eid in (None, ''):
            e.employee_id = None
        else:
            try: eid = int(eid)
            except (TypeError, ValueError): return fail('Invalid employee_id.', 422)
            emp = Employee.query.get(eid)
            if not emp or emp.branch_id != e.branch_id:
                return fail('Employee does not belong to this expense branch.', 403)
            e.employee_id = eid
    if 'payment_mode' in d and d['payment_mode']:
        e.payment_mode = d['payment_mode']
    if 'status' in d and d['status']:
        e.status = d['status']
    if 'date_incurred' in d and d['date_incurred']:
        try:
            e.date_incurred = datetime.fromisoformat(str(d['date_incurred'])).replace(tzinfo=None)
        except Exception:
            try:
                e.date_incurred = datetime.strptime(str(d['date_incurred']), '%Y-%m-%d')
            except Exception:
                pass
    db.session.commit()
    return ok(expense_dict(e), 'Expense updated.')

@api_bp.delete('/expenses/<int:expense_id>/')
@api_token_required
def expense_delete(expense_id):
    e = Expense.query.get_or_404(expense_id)
    own_branch_id = _employee_branch_id()
    if own_branch_id is not None and e.branch_id != own_branch_id:
        return fail('Employees can only access expenses in their assigned branch.', 403)
    if not _employee_can_access_expense(e):
        return fail('Employees cannot delete salary records.', 403)
    e.status = 'Cancelled'
    db.session.commit()
    return ok(expense_dict(e), 'Expense cancelled successfully.')

@api_bp.get('/expenses/categories/')
@api_token_required
def expense_categories():
    cats = ExpenseCategory.query.filter(func.lower(ExpenseCategory.name) != 'marketing').order_by(ExpenseCategory.name.asc()).all()
    non_other = [c for c in cats if c.name.lower() != 'other']
    other_cats = [c for c in cats if c.name.lower() == 'other']
    return ok([expense_category_dict(x) for x in (non_other + other_cats)])


@api_bp.post('/expenses/categories/')
@api_token_required
def expense_category_create():
    d = body()
    name = (d.get('name') or '').strip()
    if not name:
        return fail('Category name is required.', 422)
    if ExpenseCategory.query.filter(func.lower(ExpenseCategory.name) == name.lower()).first():
        return fail('Category already exists.', 409)
    x = ExpenseCategory(name=name, status='Active')
    db.session.add(x)
    db.session.commit()
    return ok(expense_category_dict(x), 'Category created.', 201)

@api_bp.post('/expenses/categories/<int:category_id>/toggle/')
@api_bp.patch('/expenses/categories/<int:category_id>/status/')
@api_token_required
def expense_category_toggle(category_id):
    c = ExpenseCategory.query.get_or_404(category_id)
    d = body() if request.data else {}
    if 'status' in d and d['status']:
        c.status = d['status']
    else:
        c.status = 'Inactive' if c.status == 'Active' else 'Active'
    db.session.commit()
    return ok(expense_category_dict(c), f'Category status updated to {c.status}.')

@api_bp.get('/expenses/budgets/')
@api_token_required
def expense_budgets():
    return ok([budget_dict(x) for x in ExpenseBudget.query.order_by(ExpenseBudget.period_year.desc(), ExpenseBudget.period_month.desc()).all()])

@api_bp.get('/expenses/summary/')
@api_token_required
def expense_summary_api():
    bid = _employee_branch_required(request.args.get('branch_id', type=int))
    if g.api_identity.get('role') == 'Employee' and bid is None:
        return fail('Employees can only access their assigned branch.', 403)
    q = Expense.query.filter(Expense.status == 'Active')
    if bid:
        q = q.filter(Expense.branch_id == bid)
    rows = q.all()
    total = sum(e.amount or 0 for e in rows)
    by_category = {}
    for e in rows:
        by_category[e.category] = (by_category.get(e.category) or 0) + (e.amount or 0)
    return ok({'total': total, 'count': len(rows), 'by_category': by_category})


# Employee Management API
@api_bp.get('/employees/')
@api_token_required
def employees():
    bid = request.args.get('branch_id', type=int)
    q = Employee.query
    if g.api_identity.get('role') == 'Employee':
        own_id = int(g.api_identity.get('employee_id') or g.api_identity.get('sub'))
        q = q.filter(Employee.id == own_id)
    if bid: q = q.filter(Employee.branch_id == bid)
    status = (request.args.get('status') or '').strip()
    if status: q = q.filter(Employee.status == status)
    term = (request.args.get('q') or '').strip()
    if term:
        like=f'%{term}%'
        q=q.filter(or_(Employee.employee_id.ilike(like), Employee.full_name.ilike(like), Employee.designation.ilike(like), Employee.contact_number.ilike(like)))
    return ok([employee_dict(e) for e in q.order_by(Employee.full_name.asc()).all()])

@api_bp.post('/employees/')
@api_token_required
def employee_create():
    if g.api_identity.get('role') != 'Admin':
        return fail('Only administrators can create employees.', 403)
    d=body()
    try: bid=int(d.get('branch_id'))
    except (TypeError,ValueError): return fail('branch_id is required.',422)
    branch=Branch.query.get(bid)
    if not branch or branch.status != 'Active': return fail('Active branch not found.',404)
    code=(d.get('employee_id') or d.get('employee_code') or '').strip()
    name=(d.get('full_name') or d.get('name') or '').strip()
    designation=(d.get('designation') or '').strip()
    username=(d.get('username') or '').strip()
    password=str(d.get('password') or '')
    if not code or not name or not designation: return fail('Employee code, name and designation are required.',422)
    if not username or not password: return fail('Username and password are required for employee login.',422)
    if Employee.query.filter_by(employee_id=code).first(): return fail('Employee code already exists.',409)
    if EmployeeCredential.query.filter_by(username=username).first(): return fail('Username already exists.',409)
    try: joining=datetime.strptime(str(d.get('joining_date')), '%Y-%m-%d').date()
    except Exception: return fail('joining_date must be YYYY-MM-DD.',422)
    try: salary=float(d.get('basic_salary') or 0)
    except (TypeError,ValueError): return fail('basic_salary must be numeric.',422)
    from werkzeug.security import generate_password_hash
    e=Employee(employee_id=code, full_name=name, designation=designation, branch_id=bid,
               contact_number=d.get('contact_number') or d.get('phone'), email=d.get('email'),
               joining_date=joining, address=d.get('address'), basic_salary=salary,
               status=d.get('status') or 'Active')
    db.session.add(e); db.session.flush()
    credential=EmployeeCredential(employee_id=e.id, username=username, password_hash=generate_password_hash(password))
    db.session.add(credential); db.session.commit()
    return ok(employee_dict(e),'Employee created.',201)

@api_bp.get('/employees/<int:employee_id>/')
@api_token_required
def employee_get(employee_id):
    if g.api_identity.get('role') == 'Employee':
        own_id = int(g.api_identity.get('employee_id') or g.api_identity.get('sub'))
        if employee_id != own_id:
            return fail('Employees can only access their own profile.', 403)
    e=Employee.query.get_or_404(employee_id)
    bid=request.args.get('branch_id',type=int)
    if bid and e.branch_id != bid: return fail('Employee does not belong to selected branch.',403)
    return ok(employee_dict(e))

@api_bp.put('/employees/<int:employee_id>/')
@api_bp.patch('/employees/<int:employee_id>/')
@api_token_required
def employee_update(employee_id):
    if g.api_identity.get('role') != 'Admin':
        return fail('Only administrators can update employees.', 403)
    e=Employee.query.get_or_404(employee_id); d=body()
    if d.get('branch_id') is not None and int(d['branch_id']) != e.branch_id: return fail('Employee branch cannot be changed.',403)
    if 'employee_id' in d or 'employee_code' in d:
        code=(d.get('employee_id') or d.get('employee_code') or '').strip()
        if code and code != e.employee_id and Employee.query.filter_by(employee_id=code).first(): return fail('Employee code already exists.',409)
        if code: e.employee_id=code
    for key in ('full_name','designation','contact_number','email','address','status','exit_reason','exit_remarks'):
        if key in d: setattr(e,key,d[key])
    if 'joining_date' in d and d['joining_date']:
        try:e.joining_date=datetime.strptime(str(d['joining_date'])[:10],'%Y-%m-%d').date()
        except Exception:return fail('joining_date must be YYYY-MM-DD.',422)
    if 'exit_date' in d and d['exit_date']:
        try:e.exit_date=datetime.strptime(str(d['exit_date'])[:10],'%Y-%m-%d').date()
        except Exception:return fail('exit_date must be YYYY-MM-DD.',422)
    if 'basic_salary' in d:
        try:e.basic_salary=float(d['basic_salary'])
        except (TypeError,ValueError):return fail('basic_salary must be numeric.',422)
    username = (d.get('username') or '').strip() if 'username' in d else None
    password = str(d.get('password') or '') if 'password' in d else None
    if username is not None or password is not None:
        from werkzeug.security import generate_password_hash
        credential = EmployeeCredential.query.filter_by(employee_id=e.id).first()
        if username:
            existing = EmployeeCredential.query.filter_by(username=username).first()
            if existing and (credential is None or existing.id != credential.id):
                return fail('Username already exists.',409)
        if credential is None:
            if not username or not password:
                return fail('Username and password are required to create employee login.',422)
            credential = EmployeeCredential(employee_id=e.id, username=username, password_hash=generate_password_hash(password))
            db.session.add(credential)
        else:
            if username:
                credential.username = username
            if password:
                credential.password_hash = generate_password_hash(password)
    db.session.commit(); return ok(employee_dict(e),'Employee updated.')

@api_bp.delete('/employees/<int:employee_id>/')
@api_token_required
def employee_delete(employee_id):
    if g.api_identity.get('role') != 'Admin':
        return fail('Only administrators can delete employees.', 403)
    e=Employee.query.get_or_404(employee_id)
    linked=Expense.query.filter(Expense.employee_id==e.id).count()
    if linked:
        e.status='Inactive'; db.session.commit(); return ok(employee_dict(e),'Employee has linked financial records and was marked inactive.')
    e.status='Inactive'; db.session.commit(); return ok(employee_dict(e),'Employee deactivated successfully.')

@api_bp.get('/employees/<int:employee_id>/salary-history/')
@api_token_required
def employee_salary_history(employee_id):
    if g.api_identity.get('role') == 'Employee':
        own_id = int(g.api_identity.get('employee_id') or g.api_identity.get('sub'))
        if employee_id != own_id:
            return fail('Employees can only view their own salary history.', 403)
    e=Employee.query.get_or_404(employee_id)
    bid=request.args.get('branch_id',type=int)
    if bid and e.branch_id != bid: return fail('Employee does not belong to selected branch.',403)
    rows=Expense.query.filter(Expense.employee_id==e.id, Expense.branch_id==e.branch_id).order_by(Expense.date_incurred.desc()).all()
    return ok([salary_expense_dict(x) for x in rows])

# ============================================================
# Voucher Management API
# ============================================================
from apps.models import VoucherBatch, Voucher, VoucherStudent, VoucherSaleHistory


def _voucher_student_json(s):
    if not s:
        return None
    return {
        'id': s.id,
        'name': s.full_name,
        'mobile': s.mobile,
        'email': s.email,
        'address': s.address,
        'id_number': s.id_number,
    }


def _voucher_json(v):
    sale = sorted(v.sale_history or [], key=lambda x: x.sold_at or datetime.min, reverse=True)
    latest = sale[0] if sale else None
    student = latest.voucher_student if latest else None
    return {
        'id': v.id,
        'voucher_code': v.voucher_code,
        'voucher_id': v.voucher_code,
        'batch_id': v.batch_id,
        'batch_number': v.batch.batch_number if v.batch else None,
        'purchase_cost': v.purchase_cost,
        'selling_price': v.selling_price,
        'profit': v.profit,
        'status': 'Sold' if v.status == 'Assigned' else v.status,
        'student_id': student.id if student else None,
        'student_name': student.full_name if student else None,
        'student_mobile': student.mobile if student else None,
        'student_email': student.email if student else None,
        'student_address': student.address if student else None,
        'student_id_number': student.id_number if student else None,
        'exam_type_id': v.exam_type_id,
        'exam_type_name': v.exam_type.name if v.exam_type else None,
        'branch_id': v.branch_id,
        'branch_name': v.branch.branch_name if v.branch else None,
        'issued_at': v.issued_at.isoformat() if v.issued_at else None,
        'used_at': v.used_at.isoformat() if v.used_at else None,
        'payment_status': latest.payment_status if latest else v.payment_status,
        'payment_mode': latest.payment_mode if latest else v.payment_mode,
        'payment_reference': latest.payment_reference if latest else v.payment_reference,
        'notes': latest.notes if latest else v.notes,
        'sold_at': latest.sold_at.isoformat() if latest else None,
        'sale_id': latest.id if latest else None,
        'sale_final_amount': latest.final_amount if latest else None,
    }


def _voucher_history_json(h):
    return {
        'id': h.id,
        'voucher_id': h.voucher_id,
        'voucher_code': h.voucher.voucher_code if h.voucher else None,
        'exam_type_id': h.voucher.exam_type_id if h.voucher else None,
        'exam_type_name': h.voucher.exam_type.name if h.voucher and h.voucher.exam_type else None,
        'student_id': h.voucher_student_id,
        'student_name': h.student_name,
        'mobile': h.mobile,
        'email': h.email,
        'address': h.address,
        'id_number': h.id_number,
        'selling_price': h.selling_price,
        'discount': h.discount,
        'final_amount': h.final_amount,
        'payment_status': h.payment_status,
        'payment_mode': h.payment_mode,
        'payment_reference': h.payment_reference,
        'notes': h.notes,
        'sold_at': h.sold_at.isoformat() if h.sold_at else None,
    }


@api_bp.get('/vouchers/')
@api_token_required
def voucher_list_api():
    q = Voucher.query
    bid = request.args.get('branch_id', type=int)
    status = (request.args.get('status') or '').strip()
    search = (request.args.get('q') or '').strip()
    if bid:
        q = q.filter(Voucher.branch_id == bid)
    if status and status != 'All':
        if status == 'Sold':
            q = q.filter(Voucher.status.in_(['Sold', 'Assigned', 'Used']))
        else:
            q = q.filter(Voucher.status == status)
    rows = q.order_by(Voucher.id.desc()).all()
    if search:
        like = search.lower()
        rows = [v for v in rows if like in v.voucher_code.lower() or any(
            like in (getattr(h, field, '') or '').lower()
            for h in (v.sale_history or [])
            for field in ('student_name', 'mobile', 'email', 'id_number')
        )]
    return ok([_voucher_json(v) for v in rows])


@api_bp.get('/vouchers/dashboard/')
@api_token_required
def voucher_dashboard_api():
    bid = request.args.get('branch_id', type=int)
    q = Voucher.query
    if bid:
        q = q.filter(Voucher.branch_id == bid)
    available = q.filter(Voucher.status == 'Available').count()
    sold_rows = q.filter(Voucher.status.in_(['Sold', 'Assigned', 'Used'])).all()
    used = q.filter(Voucher.status == 'Used').count()
    batches = VoucherBatch.query
    if bid:
        batches = batches.filter(VoucherBatch.branch_id == bid)
    purchased = int(batches.with_entities(func.coalesce(func.sum(VoucherBatch.quantity), 0)).scalar() or 0)
    purchase_cost = float(batches.with_entities(func.coalesce(func.sum(VoucherBatch.total_cost), 0)).scalar() or 0)
    history_q = VoucherSaleHistory.query.join(Voucher)
    if bid:
        history_q = history_q.filter(Voucher.branch_id == bid)
    histories = history_q.all()
    sales = sum(float(h.final_amount or 0) for h in histories)
    cost = sum(float(h.voucher.purchase_cost or 0) for h in histories)
    return ok({
        'purchased': purchased,
        'available': available,
        'issued': len(sold_rows),
        'used': used,
        'purchase_cost': purchase_cost,
        'sales_revenue': sales,
        'realized_profit': sales - cost,
        'stock_value': sum(float(v.purchase_cost or 0) for v in q.filter(Voucher.status == 'Available').all()),
        'sale_count': len(histories),
    })


@api_bp.get('/vouchers/students/')
@api_token_required
def voucher_students_api():
    rows = VoucherStudent.query.order_by(VoucherStudent.full_name.asc()).all()
    return ok([_voucher_student_json(s) for s in rows])


@api_bp.get('/vouchers/history/')
@api_token_required
def voucher_history_api():
    bid = request.args.get('branch_id', type=int)
    q = VoucherSaleHistory.query.join(Voucher)
    if bid:
        q = q.filter(Voucher.branch_id == bid)
    rows = q.order_by(VoucherSaleHistory.sold_at.desc(), VoucherSaleHistory.id.desc()).all()
    return ok([_voucher_history_json(h) for h in rows])


@api_bp.get('/vouchers/<int:voucher_id>/details/')
@api_token_required
def voucher_details_api(voucher_id):
    v = Voucher.query.get_or_404(voucher_id)
    return ok({
        'voucher': _voucher_json(v),
        'purchase': {
            'batch_number': v.batch.batch_number if v.batch else None,
            'supplier': v.batch.supplier if v.batch else None,
            'purchase_date': v.batch.purchase_date.isoformat() if v.batch and v.batch.purchase_date else None,
            'purchase_cost': v.purchase_cost,
            'branch_name': v.branch.branch_name if v.branch else None,
        },
        'history': [_voucher_history_json(h) for h in sorted(v.sale_history or [], key=lambda x: x.sold_at or datetime.min, reverse=True)],
    })


@api_bp.post('/vouchers/purchase/')
@api_token_required
def voucher_purchase_api():
    d = body()
    try:
        quantity = int(d.get('quantity') or 0)
        cost = float(d.get('cost_per_voucher') or 0)
        selling = float(d.get('selling_price') or 0)
    except (ValueError, TypeError):
        return fail('Invalid quantity or amount.', 422)
    codes = [str(x).strip() for x in (d.get('voucher_codes') or []) if str(x).strip()]
    if quantity <= 0 or cost <= 0:
        return fail('Quantity and purchase cost must be greater than 0.', 422)
    if codes and len(codes) != quantity:
        return fail('voucher_codes count must equal quantity.', 422)
    exam_type_id = d.get('exam_type_id')
    if not str(exam_type_id).isdigit():
        return fail('Exam type is required.', 422)
    exam = ExamType.query.get(int(exam_type_id))
    if not exam:
        return fail('Selected exam type not found.', 404)
    if not codes:
        prefix = str(d.get('code_prefix') or 'VCH').upper()
        import uuid
        codes = [f'{prefix}-{datetime.utcnow().strftime("%Y%m%d")}-{uuid.uuid4().hex[:8].upper()}' for _ in range(quantity)]
    if Voucher.query.filter(Voucher.voucher_code.in_(codes)).first():
        return fail('One or more voucher codes already exist.', 409)
    bid = d.get('branch_id')
    batch = VoucherBatch(
        batch_number=f'VB-{datetime.utcnow().strftime("%Y%m%d%H%M%S%f")}',
        supplier=d.get('supplier'),
        purchase_date=datetime.strptime(d.get('purchase_date'), '%Y-%m-%d').date() if d.get('purchase_date') else datetime.utcnow().date(),
        quantity=quantity, cost_per_voucher=cost, default_selling_price=selling,
        total_cost=quantity * cost, notes=d.get('notes'),
        branch_id=int(bid) if str(bid).isdigit() else None,
    )
    db.session.add(batch); db.session.flush()
    cat = ExpenseCategory.query.filter(func.lower(ExpenseCategory.name) == 'exam voucher purchase').first()
    if not cat:
        cat = ExpenseCategory(name='Exam Voucher Purchase', status='Active'); db.session.add(cat); db.session.flush()
    expense = Expense(
        category=cat.name, category_id=cat.id, amount=quantity * cost,
        description=f'Bulk exam voucher purchase - {batch.batch_number} ({quantity} vouchers, {exam.name})',
        date_incurred=datetime.combine(batch.purchase_date, datetime.min.time()), branch_id=batch.branch_id,
        payment_mode=d.get('payment_mode') or 'Other', status='Active'
    )
    db.session.add(expense); db.session.flush(); batch.expense_id = expense.id
    for code in codes:
        db.session.add(Voucher(voucher_code=code, batch_id=batch.id, purchase_cost=cost, selling_price=selling,
                                branch_id=batch.branch_id, exam_type_id=exam.id, status='Available'))
    db.session.commit()
    return ok({'batch_id': batch.id, 'batch_number': batch.batch_number, 'quantity': quantity,
                'exam_type_id': exam.id, 'exam_type_name': exam.name, 'expense_id': expense.id},
               'Voucher purchase recorded.', 201)


@api_bp.post('/vouchers/sell/')
@api_token_required
def voucher_sell_api():
    d = body()
    voucher_id = d.get('voucher_id')
    if not str(voucher_id).isdigit():
        return fail('Voucher ID is required.', 422)
    v = Voucher.query.get(int(voucher_id))
    if not v or v.status != 'Available':
        return fail('Selected voucher is not available.', 409)

    name = str(d.get('student_name') or '').strip()
    if not name:
        return fail('Student name is required.', 422)
    mobile = str(d.get('mobile') or '').strip() or None
    email = str(d.get('email') or '').strip() or None
    address = str(d.get('address') or '').strip() or None
    id_number = str(d.get('id_number') or '').strip() or None
    try:
        selling = float(d.get('selling_price') if d.get('selling_price') is not None else v.selling_price or 0)
        discount = float(d.get('discount') or 0)
    except (ValueError, TypeError):
        return fail('Invalid selling price or discount.', 422)
    final_amount = max(0.0, selling - discount)

    # Reuse a voucher-only student by mobile/email when possible; otherwise create one.
    student = None
    if mobile:
        student = VoucherStudent.query.filter(VoucherStudent.mobile == mobile).first()
    if not student and email:
        student = VoucherStudent.query.filter(VoucherStudent.email == email).first()
    if not student:
        student = VoucherStudent(full_name=name, mobile=mobile, email=email, address=address, id_number=id_number)
        db.session.add(student); db.session.flush()
    else:
        student.full_name = name
        student.mobile = mobile
        student.email = email
        student.address = address
        student.id_number = id_number

    sold_at = datetime.utcnow()
    history = VoucherSaleHistory(
        voucher_id=v.id, voucher_student_id=student.id,
        student_name=name, mobile=mobile, email=email, address=address, id_number=id_number,
        selling_price=selling, discount=discount, final_amount=final_amount,
        payment_status=str(d.get('payment_status') or 'Pending'),
        payment_mode=str(d.get('payment_mode') or '').strip() or None,
        payment_reference=str(d.get('payment_reference') or '').strip() or None,
        notes=str(d.get('notes') or '').strip() or None,
        sold_at=sold_at,
    )
    db.session.add(history)
    v.status = 'Sold'
    v.issued_at = sold_at
    v.payment_status = history.payment_status
    v.payment_mode = history.payment_mode
    v.payment_reference = history.payment_reference
    v.notes = history.notes
    v.selling_price = selling
    db.session.commit()
    return ok({'voucher': _voucher_json(v), 'sale': _voucher_history_json(history)}, 'Voucher sold successfully.', 201)


@api_bp.post('/vouchers/<int:voucher_id>/assign/')
@api_token_required
def voucher_assign_api(voucher_id):
    # Backward-compatible endpoint for older clients. New UI uses /sell/ and
    # never reads/writes Exam Management Candidate records.
    d = body()
    if d.get('student_name'):
        d['voucher_id'] = voucher_id
        return voucher_sell_api()
    return fail('Voucher sales now require voucher student details. Use the Sell Voucher form.', 422)


@api_bp.post('/vouchers/<int:voucher_id>/use/')
@api_token_required
def voucher_use_api(voucher_id):
    v = Voucher.query.get_or_404(voucher_id)
    if v.status not in ('Sold', 'Assigned'):
        return fail('Only sold vouchers can be marked as used.', 409)
    v.status = 'Used'
    v.used_at = datetime.utcnow()
    db.session.commit()
    return ok(_voucher_json(v), 'Voucher marked as used.')