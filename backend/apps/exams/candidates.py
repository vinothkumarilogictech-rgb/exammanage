import os
from datetime import date
from flask import Blueprint, render_template, request, redirect, url_for, flash, jsonify, current_app
from apps.models import (
    db, Candidate, ExamAttempt, ExamSession, SessionCandidate, Branch, ExamType, BranchExam, ExamTeam
)
from apps.exams.audit import log_action

candidates_bp = Blueprint('candidates', __name__, url_prefix='/exams/candidates')

# Statuses an administrator can explicitly set on an exam attempt.
# 'Rescheduled' is a supported action here (asks for a new date + reason)
# but is stored back as 'Scheduled' on the attempt once applied - see
# update_status() below. The calendar/candidate history still show a
# 'Rescheduled' marker on the *original* date via ExamAttempt.was_rescheduled,
# so no historical information is lost.
ATTEMPT_STATUSES = ['Registered', 'Completed', 'Rescheduled', 'Not Completed', 'Scheduled', 'No Show', 'Cancelled']
RESULT_OPTIONS = ['Pending', 'Pass', 'Fail']


def _today_str():
    return date.today().strftime('%Y-%m-%d')


def _branches_and_exam_types():
    branches = Branch.query.order_by(Branch.name).all()
    exam_types = ExamType.query.order_by(ExamType.name).all()
    exam_type_options = [{'id': e.id, 'name': e.name} for e in exam_types]
    branch_exam_map = [
        {'branch_id': m.branch_id, 'exam_type_id': m.exam_type_id}
        for m in BranchExam.query.filter_by(status='Active').all()
    ]
    return branches, exam_type_options, branch_exam_map


def _exam_session_options():
    """Sessions a candidate can actually be booked into right now (i.e. not
    already Cancelled/Completed), for the Session dropdown on Add Candidate.
    """
    sessions = (
        ExamSession.query
        .join(BranchExam, ExamSession.branch_exam_id == BranchExam.id)
        .filter(ExamSession.status.in_(['Scheduled', 'Rescheduled']))
        .order_by(ExamSession.exam_date.asc())
        .all()
    )
    options = []
    for s in sessions:
        date_label = s.exam_date.strftime('%d-%b-%Y') if s.exam_date else '-'
        options.append({
            'id': s.id,
            'branch_id': s.branch_exam.branch_id,
            'exam_type_id': s.branch_exam.exam_type_id,
            'exam_date': s.exam_date.strftime('%Y-%m-%d') if s.exam_date else '',
            'label': f"{date_label}, {s.start_time}-{s.end_time} (Seats {s.seats_taken}/{s.seat_capacity})",
        })
    return options


@candidates_bp.route('/')
def list_candidates():
    """Attempt-level listing (one row per exam attempt, across all
    candidates) so every filter in the BRD - status, result, branch, exam
    type, exam date, attempt number, and candidate search - works directly
    against real attempt records instead of only a candidate's latest
    status.
    """
    search = request.args.get('q', '').strip()
    status_filter = request.args.get('status', '').strip()
    result_filter = request.args.get('result', '').strip()
    test_type_filter = request.args.get('test_type', '').strip()
    branch_filter = request.args.get('branch_id', '').strip()
    exam_date_filter = request.args.get('exam_date', '').strip()
    attempt_filter = request.args.get('attempt', '').strip()

    # Explicit onclauses: both Candidate and ExamAttempt have their own FK to
    # Branch, so a plain .join(Branch) is ambiguous - it doesn't know
    # whether to join via Candidate.branch_id or ExamAttempt.branch_id.
    query = (
        ExamAttempt.query
        .join(Candidate, ExamAttempt.candidate_id == Candidate.id)
        .join(ExamType, ExamAttempt.exam_type_id == ExamType.id)
        .join(Branch, ExamAttempt.branch_id == Branch.id)
    )

    if search:
        like = f'%{search}%'
        query = query.filter(db.or_(
            Candidate.name.ilike(like),
            Candidate.register_number.ilike(like),
            Candidate.passport_number.ilike(like),
            Candidate.passport_full_name.ilike(like)
        ))
    if status_filter == 'Rescheduled':
        query = query.filter(ExamAttempt.original_scheduled_date != ExamAttempt.scheduled_date)
    elif status_filter:
        query = query.filter(ExamAttempt.status == status_filter)
    if result_filter:
        query = query.filter(ExamAttempt.result == result_filter)
    if test_type_filter:
        query = query.filter(ExamType.name == test_type_filter)
    if branch_filter:
        query = query.filter(ExamAttempt.branch_id == int(branch_filter))
    if exam_date_filter:
        query = query.filter(db.or_(ExamAttempt.scheduled_date == exam_date_filter,
                                     ExamAttempt.actual_exam_date == exam_date_filter))
    if attempt_filter:
        query = query.filter(ExamAttempt.attempt_number == int(attempt_filter))

    # Respect the global active-branch selector (BRD #14) - only applied
    # when the user hasn't already picked a specific branch in the filter bar.
    from flask import session as flask_session
    active_branch_id = flask_session.get('active_branch_id')
    if active_branch_id and not branch_filter:
        query = query.filter(ExamAttempt.branch_id == int(active_branch_id))

    attempts = query.order_by(ExamAttempt.id.desc()).all()

    test_type_rows = db.session.query(ExamType.name).distinct().order_by(ExamType.name.asc()).all()
    test_types = [row[0] for row in test_type_rows]

    branches, exam_type_options, branch_exam_map = _branches_and_exam_types()
    session_options = _exam_session_options()
    teams = ExamTeam.query.filter_by(status='Active').order_by(ExamTeam.name.asc()).all()

    return render_template(
        'candidates.html',
        attempts=attempts,
        search=search,
        statuses=ATTEMPT_STATUSES,
        status_filter=status_filter,
        results=RESULT_OPTIONS,
        result_filter=result_filter,
        test_types=test_types,
        test_type_filter=test_type_filter,
        branch_filter=branch_filter,
        exam_date_filter=exam_date_filter,
        attempt_filter=attempt_filter,
        branches=branches,
        exam_type_options=exam_type_options,
        branch_exam_map=branch_exam_map,
        session_options=session_options,
        teams=teams,
    )


def _validate_branch_exam(branch_id, exam_type_id):
    branch = Branch.query.get(int(branch_id)) if branch_id else None
    exam_type = ExamType.query.get(int(exam_type_id)) if exam_type_id else None
    if not branch or not exam_type:
        return None, None, 'Selected Branch or Exam Type is invalid.'
    has_branch_mappings = BranchExam.query.filter_by(branch_id=branch.id, status='Active').count() > 0
    if has_branch_mappings:
        mapping = BranchExam.query.filter_by(branch_id=branch.id, exam_type_id=exam_type.id, status='Active').first()
        if not mapping:
            return None, None, f'{exam_type.name} is not available at {branch.name}. Please choose a different exam type.'
    return branch, exam_type, None


@candidates_bp.route('/scan-passport', methods=['POST', 'OPTIONS'], strict_slashes=False)
@candidates_bp.route('/scan-passport/', methods=['POST', 'OPTIONS'], strict_slashes=False)
def scan_passport():
    if request.method == 'OPTIONS':
        return ('', 204)
    from apps.exams.passport_service import extract_passport_data_with_groq
    front_file = request.files.get('front_page') or request.files.get('front_image')
    last_file = request.files.get('last_page') or request.files.get('last_image')
    if not front_file and not last_file:
        return jsonify({'success': False, 'message': 'Please upload at least one passport page (front or last).'}), 400

    upload_folder = os.path.join(current_app.root_path, '..', 'static', 'uploads', 'passports')
    result = extract_passport_data_with_groq(front_file, last_file, upload_folder=upload_folder)
    return jsonify(result), (200 if result.get('success') or result.get('error_code') == 'GROQ_KEY_NOT_CONFIGURED' else 422)


@candidates_bp.route('/save', methods=['POST'])
def save_candidate():
    """Add Candidate (creates the Candidate master + its first Attempt) or
    Edit Candidate (updates the master profile fields only; the exam
    scheduling fields for an existing candidate are changed via Attempt
    actions - Status/Reschedule/Retest - so a completed/cancelled attempt's
    history is never silently rewritten here).
    """
    candidate_id = request.form.get('id')
    name = (request.form.get('name') or '').strip()
    register_number = (request.form.get('register_number') or '').strip()
    email = (request.form.get('email') or '').strip() or None
    phone = (request.form.get('phone') or '').strip() or None
    team_id_raw = (request.form.get('team_id') or '').strip()
    team_id = int(team_id_raw) if team_id_raw.isdigit() else None
    reason_note = (request.form.get('remarks') or request.form.get('reason_note') or '').strip() or None

    # Passport & Address fields
    passport_number = (request.form.get('passport_number') or '').strip() or None
    passport_full_name = (request.form.get('passport_full_name') or '').strip() or None
    passport_dob = (request.form.get('passport_dob') or request.form.get('dob') or '').strip() or None
    passport_gender = (request.form.get('passport_gender') or '').strip() or None
    passport_nationality = (request.form.get('passport_nationality') or request.form.get('nationality') or '').strip() or None
    passport_issue_date = (request.form.get('passport_issue_date') or '').strip() or None
    passport_expiry_date = (request.form.get('passport_expiry_date') or '').strip() or None
    address_line_1 = (request.form.get('address_line_1') or '').strip() or None
    address_line_2 = (request.form.get('address_line_2') or '').strip() or None
    city = (request.form.get('city') or '').strip() or None
    state = (request.form.get('state') or '').strip() or None
    postal_code = (request.form.get('postal_code') or '').strip() or None
    country = (request.form.get('country') or '').strip() or None
    passport_scan_date = (request.form.get('passport_scan_date') or '').strip() or None
    passport_front_image = (request.form.get('passport_front_image') or '').strip() or None
    passport_last_image = (request.form.get('passport_last_image') or '').strip() or None

    branch_id = (request.form.get('branch_id') or '').strip()
    exam_type_id = (request.form.get('exam_type_id') or '').strip()
    exam_date = (request.form.get('exam_date') or '').strip()
    session_id = (request.form.get('session_id') or '').strip()
    next_url = request.form.get('next') or url_for('candidates.list_candidates')

    if not name:
        flash('Candidate name is required.', 'error')
        return redirect(next_url)

    status_req = (request.form.get('status') or '').strip()
    status = status_req if status_req in ('Registered', 'Not Completed', 'Rescheduled', 'Completed') else 'Registered'

    if candidate_id:
        candidate = Candidate.query.get_or_404(int(candidate_id))
        candidate.name = name
        if register_number:
            candidate.register_number = register_number
        candidate.email = email
        candidate.phone = phone
        candidate.team_id = team_id
        if status_req:
            candidate.status = status
        if reason_note:
            candidate.reason_note = reason_note
        if branch_id and branch_id.isdigit():
            candidate.branch_id = int(branch_id)
        if exam_type_id and exam_type_id.isdigit():
            candidate.exam_type_id = int(exam_type_id)
            et = ExamType.query.get(int(exam_type_id))
            if et:
                candidate.test_type = et.name
        if exam_date:
            candidate.exam_date = exam_date
            if status == 'Rescheduled':
                candidate.rescheduled_date = exam_date

        candidate.passport_number = passport_number
        candidate.passport_full_name = passport_full_name
        candidate.passport_dob = passport_dob
        candidate.dob = passport_dob
        candidate.passport_gender = passport_gender
        candidate.passport_nationality = passport_nationality
        candidate.nationality = passport_nationality
        candidate.passport_issue_date = passport_issue_date
        candidate.passport_expiry_date = passport_expiry_date
        candidate.address_line_1 = address_line_1
        candidate.address_line_2 = address_line_2
        candidate.city = city
        candidate.state = state
        candidate.postal_code = postal_code
        candidate.country = country
        if passport_scan_date:
            candidate.passport_scan_date = passport_scan_date
        if passport_front_image:
            candidate.passport_front_image = passport_front_image
        if passport_last_image:
            candidate.passport_last_image = passport_last_image

        # Sync latest attempt
        latest = ExamAttempt.query.filter_by(candidate_id=candidate.id).order_by(ExamAttempt.attempt_number.desc()).first()
        if latest:
            if candidate.branch_id:
                latest.branch_id = candidate.branch_id
            if candidate.exam_type_id:
                latest.exam_type_id = candidate.exam_type_id
            if candidate.exam_date:
                latest.scheduled_date = candidate.exam_date
            if status == 'Completed':
                latest.status = 'Completed'
                latest.actual_exam_date = candidate.exam_date or _today_str()
            elif status == 'Not Completed':
                latest.status = 'No Show'
            elif status == 'Rescheduled':
                if not latest.original_scheduled_date:
                    latest.original_scheduled_date = latest.scheduled_date
                if candidate.exam_date:
                    latest.scheduled_date = candidate.exam_date
                latest.status = 'Scheduled'
            else:
                latest.status = 'Scheduled'

        db.session.commit()
        flash('Candidate profile updated.', 'success')
        return redirect(next_url)

    # New candidate: requires branch, exam type, and exam date
    if not branch_id:
        flash('Branch / Exam Center is required.', 'error')
        return redirect(next_url)
    if not exam_type_id:
        flash('Exam Type is required.', 'error')
        return redirect(next_url)

    branch, exam_type, error = _validate_branch_exam(branch_id, exam_type_id)
    if error:
        flash(error, 'error')
        return redirect(next_url)

    if not exam_date:
        flash('Exam Date is required.', 'error')
        return redirect(next_url)

    candidate = Candidate(
        name=name,
        email=email,
        phone=phone,
        register_number=register_number or None,
        branch_id=branch.id,
        exam_type_id=exam_type.id,
        team_id=team_id,
        test_type=exam_type.name,
        exam_date=exam_date,
        status=status,
        original_exam_date=exam_date,
        rescheduled_date=exam_date if status == 'Rescheduled' else None,
        reason_note=reason_note,
        # Passport details
        dob=passport_dob,
        passport_number=passport_number,
        nationality=passport_nationality,
        passport_full_name=passport_full_name,
        passport_dob=passport_dob,
        passport_gender=passport_gender,
        passport_nationality=passport_nationality,
        passport_issue_date=passport_issue_date,
        passport_expiry_date=passport_expiry_date,
        address_line_1=address_line_1,
        address_line_2=address_line_2,
        city=city,
        state=state,
        postal_code=postal_code,
        country=country,
        passport_scan_date=passport_scan_date,
        passport_front_image=passport_front_image,
        passport_last_image=passport_last_image,
    )
    db.session.add(candidate)
    db.session.flush()

    attempt_status = {
        'Completed': 'Completed',
        'Not Completed': 'No Show',
        'Rescheduled': 'Scheduled',
        'Registered': 'Scheduled',
    }.get(status, 'Scheduled')

    attempt = ExamAttempt(
        candidate_id=candidate.id,
        exam_type_id=exam_type.id,
        branch_id=branch.id,
        session_id=None,
        attempt_number=1,
        original_scheduled_date=exam_date,
        scheduled_date=exam_date,
        status=attempt_status,
        actual_exam_date=exam_date if attempt_status == 'Completed' else None,
        result='Pending',
    )
    db.session.add(attempt)
    db.session.flush()

    log_action('Candidate Registered', record_id=candidate.id,
                new_value=f"{candidate.name} | {exam_type.name} | {branch.name} | {exam_date} | Attempt 1")
    db.session.commit()
    flash('Candidate added.', 'success')
    return redirect(next_url)


@candidates_bp.route('/<int:candidate_id>')
def candidate_detail(candidate_id):
    candidate = Candidate.query.get_or_404(candidate_id)
    attempts = ExamAttempt.query.filter_by(candidate_id=candidate.id).order_by(ExamAttempt.attempt_number.asc()).all()
    latest = attempts[-1] if attempts else None
    branches, exam_type_options, branch_exam_map = _branches_and_exam_types()
    return render_template(
        'candidate_detail.html',
        candidate=candidate,
        attempts=attempts,
        latest=latest,
        statuses=ATTEMPT_STATUSES,
        results=RESULT_OPTIONS,
        branches=branches,
        exam_type_options=exam_type_options,
        branch_exam_map=branch_exam_map,
    )


@candidates_bp.route('/<int:candidate_id>/add-attempt', methods=['POST'])
def add_attempt(candidate_id):
    """Create a new, independent exam attempt for a candidate who is
    returning for a retest. The previous attempt(s) are never modified.
    """
    candidate = Candidate.query.get_or_404(candidate_id)
    branch_id = (request.form.get('branch_id') or '').strip()
    exam_type_id = (request.form.get('exam_type_id') or '').strip()
    exam_date = (request.form.get('exam_date') or '').strip()
    next_url = request.form.get('next') or url_for('candidates.candidate_detail', candidate_id=candidate.id)

    if not branch_id or not exam_type_id or not exam_date:
        flash('Branch, Exam Type and Exam Date are required to add a new attempt.', 'error')
        return redirect(next_url)

    branch, exam_type, error = _validate_branch_exam(branch_id, exam_type_id)
    if error:
        flash(error, 'error')
        return redirect(next_url)

    last_attempt_number = db.session.query(db.func.max(ExamAttempt.attempt_number)).filter_by(
        candidate_id=candidate.id).scalar() or 0

    attempt = ExamAttempt(
        candidate_id=candidate.id,
        exam_type_id=exam_type.id,
        branch_id=branch.id,
        attempt_number=last_attempt_number + 1,
        original_scheduled_date=exam_date,
        scheduled_date=exam_date,
        status='Scheduled',
        result='Pending',
    )
    db.session.add(attempt)
    db.session.flush()

    # Keep the candidate master's "current" legacy fields pointed at the
    # newest attempt too, purely for backward-compatible display.
    candidate.branch_id = branch.id
    candidate.exam_type_id = exam_type.id
    candidate.test_type = exam_type.name
    candidate.exam_date = exam_date
    candidate.status = 'Scheduled'

    log_action('New Exam Attempt Created (Retest)', record_id=attempt.id,
                new_value=f"{candidate.name} | Attempt {attempt.attempt_number} | {exam_type.name} | {branch.name} | {exam_date}")
    db.session.commit()
    flash(f'Attempt {attempt.attempt_number} created for {candidate.name}.', 'success')
    return redirect(next_url)


@candidates_bp.route('/attempt/status/<int:attempt_id>', methods=['POST'])
def update_attempt_status(attempt_id):
    attempt = ExamAttempt.query.get_or_404(attempt_id)
    candidate = attempt.candidate
    new_status = (request.form.get('status') or '').strip()
    reason_note = (request.form.get('reason_note') or '').strip()
    new_exam_date = (request.form.get('new_exam_date') or '').strip()
    actual_exam_date = (request.form.get('actual_exam_date') or '').strip()
    result = (request.form.get('result') or '').strip()
    next_url = request.form.get('next') or url_for('candidates.candidate_detail', candidate_id=candidate.id)

    if new_status not in ATTEMPT_STATUSES:
        flash('Invalid status selected.', 'error')
        return redirect(next_url)

    old_status = attempt.status

    if new_status == 'Rescheduled':
        if not new_exam_date:
            flash('Please select a new exam date to reschedule this attempt.', 'error')
            return redirect(next_url)
        if not attempt.original_scheduled_date:
            attempt.original_scheduled_date = attempt.scheduled_date
        old_date = attempt.scheduled_date
        attempt.scheduled_date = new_exam_date
        attempt.reschedule_reason = reason_note or attempt.reschedule_reason
        attempt.status = 'Scheduled'  # now actively scheduled again, on the new date
        candidate.status = 'Rescheduled'
        candidate.exam_date = new_exam_date
        candidate.rescheduled_date = new_exam_date
        log_action('Exam Attempt Rescheduled', record_id=attempt.id,
                    old_value=f"{candidate.name} Attempt {attempt.attempt_number}: {old_date}",
                    new_value=f"{candidate.name} Attempt {attempt.attempt_number}: {new_exam_date}",
                    reason=reason_note or None)

    elif new_status == 'Completed':
        attempt.actual_exam_date = actual_exam_date or _today_str()
        attempt.result = result if result in RESULT_OPTIONS else 'Pending'
        attempt.status = 'Completed'
        candidate.status = 'Completed'
        log_action('Exam Attempt Completed', record_id=attempt.id,
                    old_value=f"{candidate.name} Attempt {attempt.attempt_number}: {old_status}",
                    new_value=f"{candidate.name} Attempt {attempt.attempt_number}: Completed / {attempt.result}")

    elif new_status == 'Cancelled':
        attempt.cancellation_reason = reason_note or attempt.cancellation_reason
        attempt.status = 'Cancelled'
        candidate.status = 'Not Completed'
        log_action('Exam Attempt Cancelled', record_id=attempt.id,
                    old_value=f"{candidate.name} Attempt {attempt.attempt_number}: {old_status}",
                    new_value=f"{candidate.name} Attempt {attempt.attempt_number}: Cancelled",
                    reason=reason_note or None)

    elif new_status in ('No Show', 'Not Completed'):
        attempt.status = 'No Show'
        if reason_note:
            attempt.remarks = reason_note
        candidate.status = 'Not Completed'
        log_action('Exam Attempt No Show', record_id=attempt.id,
                    old_value=f"{candidate.name} Attempt {attempt.attempt_number}: {old_status}",
                    new_value=f"{candidate.name} Attempt {attempt.attempt_number}: No Show")

    else:  # 'Scheduled' / 'Registered'
        attempt.status = 'Scheduled'
        if reason_note:
            attempt.remarks = reason_note
        candidate.status = 'Registered'
        log_action('Exam Attempt Status Updated', record_id=attempt.id,
                    old_value=f"{candidate.name} Attempt {attempt.attempt_number}: {old_status}",
                    new_value=f"{candidate.name} Attempt {attempt.attempt_number}: Scheduled")

    # Keep candidate master reason/date in sync
    latest = ExamAttempt.query.filter_by(candidate_id=candidate.id).order_by(ExamAttempt.attempt_number.desc()).first()
    if latest and latest.id == attempt.id:
        candidate.exam_date = attempt.scheduled_date
        if attempt.cancellation_reason or attempt.reschedule_reason or attempt.remarks:
            candidate.reason_note = attempt.cancellation_reason or attempt.reschedule_reason or attempt.remarks

    db.session.commit()
    flash('Exam attempt status updated successfully.', 'success')
    return redirect(next_url)


@candidates_bp.route('/<int:candidate_id>/status', methods=['POST'])
def update_candidate_status(candidate_id):
    candidate = Candidate.query.get_or_404(candidate_id)
    new_status = (request.form.get('status') or '').strip()
    new_exam_date = (request.form.get('exam_date') or '').strip()
    reason_note = (request.form.get('remarks') or request.form.get('reason_note') or '').strip()
    next_url = request.form.get('next') or url_for('candidates.list_candidates')

    allowed = {'Registered', 'Not Completed', 'Rescheduled', 'Completed'}
    if new_status in allowed:
        candidate.status = new_status
        if reason_note:
            candidate.reason_note = reason_note
        if new_status == 'Rescheduled' and new_exam_date:
            candidate.rescheduled_date = new_exam_date
            candidate.exam_date = new_exam_date

        latest = ExamAttempt.query.filter_by(candidate_id=candidate.id).order_by(ExamAttempt.attempt_number.desc()).first()
        if latest:
            if new_status == 'Completed':
                latest.status = 'Completed'
                latest.actual_exam_date = candidate.exam_date or _today_str()
            elif new_status == 'Not Completed':
                latest.status = 'No Show'
            elif new_status == 'Rescheduled':
                if not latest.original_scheduled_date:
                    latest.original_scheduled_date = latest.scheduled_date
                if new_exam_date:
                    latest.scheduled_date = new_exam_date
                latest.status = 'Scheduled'
            else:  # Registered
                latest.status = 'Scheduled'

        log_action('Candidate Status Updated', record_id=candidate.id,
                   new_value=f"{candidate.name} -> {new_status}")
        db.session.commit()
        flash(f'Status for {candidate.name} updated to {new_status}.', 'success')
    else:
        flash('Invalid status.', 'error')
    return redirect(next_url)


@candidates_bp.route('/report')
def candidate_report():
    return redirect(url_for('exams_dashboard.reports', **request.args))


@candidates_bp.route('/associate/<int:session_id>', methods=['POST'])
def associate_candidate(session_id):
    session_obj = ExamSession.query.get_or_404(session_id)

    if session_obj.status == 'Cancelled':
        flash('Cannot add candidate to a cancelled session.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))

    candidate_id = request.form.get('candidate_id')
    new_name = (request.form.get('new_candidate_name') or '').strip()
    new_email = (request.form.get('new_candidate_email') or '').strip()
    new_phone = (request.form.get('new_candidate_phone') or '').strip()

    if not candidate_id and new_name:
        candidate = Candidate(name=new_name, email=new_email, phone=new_phone)
        db.session.add(candidate)
        db.session.flush()
        candidate_id = candidate.id

    if not candidate_id:
        flash('Please select or create a candidate.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))

    candidate_id = int(candidate_id)

    if session_obj.seats_taken >= session_obj.seat_capacity:
        flash('Cannot exceed seat capacity for this session.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))

    existing = SessionCandidate.query.filter_by(session_id=session_id, candidate_id=candidate_id).first()
    if existing:
        flash('This candidate is already associated with this session.', 'error')
        return redirect(url_for('sessions.session_detail', session_id=session_id))

    link = SessionCandidate(session_id=session_id, candidate_id=candidate_id)
    db.session.add(link)
    db.session.flush()
    candidate = Candidate.query.get(candidate_id)
    log_action('Candidate Associated', record_id=session_id,
                new_value=f"candidate={candidate.name if candidate else candidate_id}")
    db.session.commit()
    return redirect(url_for('sessions.session_detail', session_id=session_id))


@candidates_bp.route('/remove/<int:session_id>/<int:candidate_id>', methods=['POST'])
def remove_candidate(session_id, candidate_id):
    link = SessionCandidate.query.filter_by(session_id=session_id, candidate_id=candidate_id).first_or_404()
    candidate = Candidate.query.get(candidate_id)
    db.session.delete(link)
    log_action('Candidate Removed', record_id=session_id,
                old_value=f"candidate={candidate.name if candidate else candidate_id}")
    db.session.commit()
    return redirect(url_for('sessions.session_detail', session_id=session_id))