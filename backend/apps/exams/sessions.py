from datetime import datetime
from flask import Blueprint, render_template, request, redirect, url_for, flash
from apps.models import db, Branch, ExamType, BranchExam, ExamSession, Candidate
from apps.exams.audit import log_action

sessions_bp = Blueprint('sessions', __name__, url_prefix='/exams/sessions')


def _parse_date(value):
    try:
        return datetime.strptime(value, '%Y-%m-%d').date()
    except (TypeError, ValueError):
        return None


def _validate_session_form(form):
    errors = []
    branch_exam_id = form.get('branch_exam_id')
    exam_date = _parse_date(form.get('exam_date'))
    start_time = (form.get('start_time') or '').strip()
    end_time = (form.get('end_time') or '').strip()
    fee = form.get('fee')
    seat_capacity = form.get('seat_capacity')

    if not branch_exam_id:
        errors.append('Exam (branch mapping) is required.')
    if not exam_date:
        errors.append('Exam date is required and must be valid.')
    if not start_time:
        errors.append('Start time is required.')
    if not end_time:
        errors.append('End time is required.')
    if start_time and end_time and end_time <= start_time:
        errors.append('End time must be after start time.')
    try:
        fee_val = float(fee) if fee not in (None, '') else 0.0
        if fee_val < 0:
            errors.append('Fee cannot be negative.')
    except ValueError:
        errors.append('Fee must be a number.')
        fee_val = 0.0
    try:
        capacity_val = int(seat_capacity) if seat_capacity not in (None, '') else 0
        if capacity_val <= 0:
            errors.append('Seat capacity must be greater than 0.')
    except ValueError:
        errors.append('Seat capacity must be a whole number.')
        capacity_val = 0

    return errors, {
        'branch_exam_id': int(branch_exam_id) if branch_exam_id else None,
        'exam_date': exam_date,
        'start_time': start_time,
        'end_time': end_time,
        'fee': fee_val,
        'seat_capacity': capacity_val,
    }


@sessions_bp.route('/')
def list_sessions():
    query = ExamSession.query.join(BranchExam).join(Branch).join(ExamType)

    branch_id = request.args.get('branch_id', '').strip()
    exam_type_id = request.args.get('exam_type_id', '').strip()
    language = request.args.get('language', '').strip()
    exam_date = request.args.get('exam_date', '').strip()
    status = request.args.get('status', '').strip()

    if branch_id:
        query = query.filter(Branch.id == int(branch_id))
    if exam_type_id:
        query = query.filter(ExamType.id == int(exam_type_id))
    if language:
        query = query.filter(ExamType.language == language)
    if exam_date:
        parsed = _parse_date(exam_date)
        if parsed:
            query = query.filter(ExamSession.exam_date == parsed)
    if status:
        query = query.filter(ExamSession.status == status)

    sessions = query.order_by(ExamSession.exam_date.desc(), ExamSession.id.desc()).all()
    branches = Branch.query.filter_by(status='Active').order_by(Branch.name).all()
    exam_types = ExamType.query.filter_by(status='Active').order_by(ExamType.name).all()
    languages = [row[0] for row in db.session.query(ExamType.language).distinct().all() if row[0]]
    branch_exams = BranchExam.query.filter_by(status='Active').join(Branch).join(ExamType).all()

    return render_template('exam_sessions.html', sessions=sessions, branches=branches,
                            exam_types=exam_types, languages=languages, branch_exams=branch_exams,
                            branch_id=branch_id, exam_type_id=exam_type_id, language=language,
                            exam_date=exam_date, status=status)


@sessions_bp.route('/save', methods=['POST'])
def save_session():
    errors, data = _validate_session_form(request.form)
    session_id = request.form.get('id')

    if errors:
        for e in errors:
            flash(e, 'error')
        return redirect(url_for('sessions.list_sessions'))

    if session_id:
        session_obj = ExamSession.query.get_or_404(int(session_id))
        old_value = f"{session_obj.exam_date} {session_obj.start_time}-{session_obj.end_time}, fee={session_obj.fee}, capacity={session_obj.seat_capacity}"
        session_obj.branch_exam_id = data['branch_exam_id']
        session_obj.exam_date = data['exam_date']
        session_obj.start_time = data['start_time']
        session_obj.end_time = data['end_time']
        session_obj.fee = data['fee']
        session_obj.seat_capacity = data['seat_capacity']
        db.session.flush()
        new_value = f"{session_obj.exam_date} {session_obj.start_time}-{session_obj.end_time}, fee={session_obj.fee}, capacity={session_obj.seat_capacity}"
        log_action('Session Updated', record_id=session_obj.id, old_value=old_value, new_value=new_value)
    else:
        session_obj = ExamSession(**data, status='Scheduled')
        db.session.add(session_obj)
        db.session.flush()
        log_action('Session Created', record_id=session_obj.id,
                    new_value=f"{session_obj.exam_date} {session_obj.start_time}-{session_obj.end_time}")

    db.session.commit()
    return redirect(url_for('sessions.list_sessions'))


@sessions_bp.route('/<int:session_id>')
def session_detail(session_id):
    session_obj = ExamSession.query.get_or_404(session_id)
    all_candidates = Candidate.query.order_by(Candidate.name).all()
    return render_template('session_detail.html', s=session_obj, all_candidates=all_candidates)


@sessions_bp.route('/<int:session_id>/mark-completed', methods=['POST'])
def mark_completed(session_id):
    session_obj = ExamSession.query.get_or_404(session_id)
    if session_obj.status == 'Cancelled':
        flash('A cancelled session cannot be marked completed.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))
    old_status = session_obj.status
    session_obj.status = 'Completed'
    log_action('Status Changed', record_id=session_obj.id, old_value=old_status, new_value='Completed')
    db.session.commit()
    return redirect(url_for('sessions.session_detail', session_id=session_id))


@sessions_bp.route('/<int:session_id>/reschedule', methods=['POST'])
def reschedule_session(session_id):
    session_obj = ExamSession.query.get_or_404(session_id)

    if session_obj.status == 'Cancelled':
        flash('A cancelled session cannot be rescheduled.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))

    new_date = _parse_date(request.form.get('new_date'))
    new_start = (request.form.get('new_start_time') or '').strip()
    new_end = (request.form.get('new_end_time') or '').strip()
    reason = (request.form.get('reason') or '').strip()

    if not new_date or not new_start or not new_end:
        flash('New date/time must be valid.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))
    if new_end <= new_start:
        flash('End time must be after start time.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))

    # Preserve the original schedule the first time this session is rescheduled.
    if not session_obj.original_date:
        session_obj.original_date = session_obj.exam_date
        session_obj.original_start_time = session_obj.start_time
        session_obj.original_end_time = session_obj.end_time

    old_value = f"{session_obj.exam_date} {session_obj.start_time}-{session_obj.end_time}"
    session_obj.exam_date = new_date
    session_obj.start_time = new_start
    session_obj.end_time = new_end
    session_obj.reschedule_reason = reason
    session_obj.rescheduled_by = 'Admin'
    session_obj.rescheduled_at = datetime.utcnow()
    session_obj.status = 'Rescheduled'

    new_value = f"{new_date} {new_start}-{new_end}"
    log_action('Exam Rescheduled', record_id=session_obj.id, old_value=old_value,
                new_value=new_value, reason=reason)
    db.session.commit()
    flash('Session rescheduled successfully.', 'success')
    return redirect(url_for('sessions.session_detail', session_id=session_id))


@sessions_bp.route('/<int:session_id>/cancel', methods=['POST'])
def cancel_session(session_id):
    session_obj = ExamSession.query.get_or_404(session_id)
    reason = (request.form.get('reason') or '').strip()

    if not reason:
        flash('Cancellation reason is mandatory.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))

    old_status = session_obj.status
    session_obj.status = 'Cancelled'
    session_obj.cancellation_reason = reason
    session_obj.cancelled_by = 'Admin'
    session_obj.cancelled_at = datetime.utcnow()

    log_action('Exam Cancelled', record_id=session_obj.id, old_value=old_status,
                new_value='Cancelled', reason=reason)
    db.session.commit()
    flash('Session cancelled.', 'success')
    return redirect(url_for('sessions.session_detail', session_id=session_id))
