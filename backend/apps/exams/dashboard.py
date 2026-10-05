import csv
import io
from collections import OrderedDict
from datetime import date, datetime
from flask import Blueprint, render_template, session, request, Response, redirect, url_for
from apps.models import db, ExamType, Candidate, ExamAttempt, Branch, ExamTeam

exams_dashboard_bp = Blueprint('exams_dashboard', __name__, url_prefix='/exams')


def normalize_candidate_status(raw_status):
    """Safely map old/new candidate statuses for display and counts without corrupting data."""
    if not raw_status:
        return 'Registered'
    s = str(raw_status).strip()
    if s == 'Absent':
        return 'Not Completed'
    if s == 'Scheduled':
        return 'Registered'
    if s in ('Registered', 'Not Completed', 'Rescheduled', 'Completed'):
        return s
    return s


@exams_dashboard_bp.route('/')
def dashboard():
    active_branch_id = session.get('active_branch_id')

    # Attempt-driven stats
    attempt_query = ExamAttempt.query
    if active_branch_id:
        attempt_query = attempt_query.filter(ExamAttempt.branch_id == int(active_branch_id))
    attempts = attempt_query.all()

    scheduled_count = sum(1 for a in attempts if a.status == 'Scheduled')
    completed_count = sum(1 for a in attempts if a.status == 'Completed')
    no_show_count = sum(1 for a in attempts if a.status == 'No Show')
    rescheduled_count = sum(1 for a in attempts if a.was_rescheduled or a.status == 'Rescheduled')

    if active_branch_id:
        candidate_ids = {a.candidate_id for a in attempts}
        total_candidates = len(candidate_ids)
    else:
        total_candidates = Candidate.query.count()

    # Only remaining valid stats cards (Cancelled, Total Sessions, Completed Candidates, Available Seats removed)
    stats = {
        'total_exams': ExamType.query.count(),
        'scheduled': scheduled_count,
        'completed': completed_count,
        'rescheduled': rescheduled_count,
        'no_show': no_show_count,
        'total_candidates': total_candidates,
    }

    # Exam Activity Calendar data
    calendar_attempts = []
    for a in attempts:
        calendar_attempts.append({
            'attempt_id': a.id,
            'candidate_id': a.candidate_id,
            'name': a.candidate.name if a.candidate else '-',
            'register_number': a.candidate.register_number if a.candidate else '-',
            'test_type': a.exam_type.name if a.exam_type else '-',
            'branch_name': a.branch.name if a.branch else '-',
            'scheduled_date': a.scheduled_date,
            'original_scheduled_date': a.original_scheduled_date,
            'actual_exam_date': a.actual_exam_date,
            'status': a.status,
            'result': a.result,
            'attempt_number': a.attempt_number,
            'was_rescheduled': a.was_rescheduled,
            'session_label': (
                f"{a.session.exam_date.strftime('%d-%b-%Y')}, {a.session.start_time}-{a.session.end_time}"
                if a.session and a.session.exam_date else '-'
            ),
        })

    return render_template(
        'exam_dashboard.html',
        stats=stats,
        calendar_attempts=calendar_attempts,
        today_str=date.today().strftime('%Y-%m-%d'),
    )


def _get_filtered_report_data():
    """Shared query and filter execution for Candidate Report view and CSV export."""
    branch_filter = (request.args.get('branch_id') or '').strip()
    filter_type = (request.args.get('filter_type') or 'All').strip()
    date_filter = (request.args.get('date') or '').strip()
    month_filter = (request.args.get('month') or '').strip()
    start_date = (request.args.get('start_date') or '').strip()
    end_date = (request.args.get('end_date') or '').strip()
    exam_type_filter = (request.args.get('exam_type_id') or '').strip()
    team_filter = (request.args.get('team_id') or '').strip()
    status_filter = (request.args.get('status') or '').strip()
    search = (request.args.get('q') or '').strip()

    active_branch_id = session.get('active_branch_id')

    # Base candidate query with outer joins so candidates without team or exam type are never excluded
    query = Candidate.query.outerjoin(Branch, Candidate.branch_id == Branch.id) \
                           .outerjoin(ExamType, Candidate.exam_type_id == ExamType.id) \
                           .outerjoin(ExamTeam, Candidate.team_id == ExamTeam.id)

    if branch_filter:
        query = query.filter(Candidate.branch_id == int(branch_filter))
    elif active_branch_id:
        query = query.filter(Candidate.branch_id == int(active_branch_id))

    if exam_type_filter:
        query = query.filter(Candidate.exam_type_id == int(exam_type_filter))

    if team_filter == 'unassigned':
        query = query.filter(db.or_(Candidate.team_id == None, Candidate.team_id == 0))
    elif team_filter:
        query = query.filter(Candidate.team_id == int(team_filter))

    if search:
        like = f"%{search}%"
        query = query.filter(db.or_(
            Candidate.name.ilike(like),
            Candidate.email.ilike(like),
            Candidate.phone.ilike(like),
            Candidate.reason_note.ilike(like),
            Candidate.register_number.ilike(like),
        ))

    candidates = query.order_by(Candidate.exam_date.desc(), Candidate.id.desc()).all()

    # In-memory Date Filtering (safe against null / irregular dates)
    today_str = date.today().strftime('%Y-%m-%d')
    date_filtered = []
    for c in candidates:
        cand_date = (c.exam_date or '').strip()
        if filter_type == 'Today':
            if cand_date != today_str:
                continue
        elif filter_type == 'Date' and date_filter:
            if cand_date != date_filter:
                continue
        elif filter_type == 'Month' and month_filter:
            if not cand_date.startswith(month_filter):
                continue
        elif filter_type == 'Range' and start_date and end_date:
            if not (start_date <= cand_date <= end_date):
                continue
        date_filtered.append(c)

    # Status Filtering
    if status_filter and status_filter != 'All':
        final_candidates = [
            c for c in date_filtered
            if normalize_candidate_status(c.status).lower() == status_filter.lower()
        ]
    else:
        final_candidates = date_filtered

    # Dynamically calculate ALL counts strictly from the filtered dataset
    total_candidates = len(final_candidates)
    completed_count = sum(1 for c in final_candidates if normalize_candidate_status(c.status) == 'Completed')
    registered_count = sum(1 for c in final_candidates if normalize_candidate_status(c.status) == 'Registered')
    not_completed_count = sum(1 for c in final_candidates if normalize_candidate_status(c.status) == 'Not Completed')
    rescheduled_count = sum(1 for c in final_candidates if normalize_candidate_status(c.status) == 'Rescheduled')

    # Team-wise counts strictly computed from the filtered dataset
    team_counts = OrderedDict()
    for c in final_candidates:
        team_name = c.team.name if c.team else 'Unassigned'
        team_counts[team_name] = team_counts.get(team_name, 0) + 1

    return {
        'candidates': final_candidates,
        'total_candidates': total_candidates,
        'completed_count': completed_count,
        'registered_count': registered_count,
        'not_completed_count': not_completed_count,
        'rescheduled_count': rescheduled_count,
        'team_counts': team_counts,
        'branch_filter': branch_filter,
        'filter_type': filter_type,
        'date_filter': date_filter,
        'month_filter': month_filter,
        'start_date': start_date,
        'end_date': end_date,
        'exam_type_filter': exam_type_filter,
        'team_filter': team_filter,
        'status_filter': status_filter,
        'search': search,
    }


@exams_dashboard_bp.route('/reports')
def reports():
    data = _get_filtered_report_data()

    branches = Branch.query.order_by(Branch.name.asc()).all()
    exam_types = ExamType.query.order_by(ExamType.name.asc()).all()
    teams = ExamTeam.query.filter_by(status='Active').order_by(ExamTeam.name.asc()).all()

    return render_template(
        'exam_reports.html',
        candidates=data['candidates'],
        total_candidates=data['total_candidates'],
        completed_count=data['completed_count'],
        registered_count=data['registered_count'],
        not_completed_count=data['not_completed_count'],
        rescheduled_count=data['rescheduled_count'],
        team_counts=data['team_counts'],
        branches=branches,
        exam_types=exam_types,
        teams=teams,
        branch_filter=data['branch_filter'],
        filter_type=data['filter_type'],
        date_filter=data['date_filter'],
        month_filter=data['month_filter'],
        start_date=data['start_date'],
        end_date=data['end_date'],
        exam_type_filter=data['exam_type_filter'],
        team_filter=data['team_filter'],
        status_filter=data['status_filter'],
        search=data['search'],
        today_str=date.today().strftime('%Y-%m-%d'),
        current_month_str=date.today().strftime('%Y-%m'),
        normalize_status=normalize_candidate_status,
    )


@exams_dashboard_bp.route('/reports/export-csv')
def export_reports_csv():
    data = _get_filtered_report_data()
    candidates = data['candidates']

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        'S.No', 'Date', 'Candidate Name', 'Team', 'Exam Type',
        'Branch', 'Status', 'Remarks', 'Email', 'Phone'
    ])

    for i, c in enumerate(candidates, 1):
        writer.writerow([
            i,
            c.exam_date or '-',
            c.name or '-',
            c.team.name if c.team else 'Unassigned',
            c.exam_type.name if c.exam_type else (c.test_type or '-'),
            c.branch.name if c.branch else '-',
            normalize_candidate_status(c.status),
            c.reason_note or '-',
            c.email or '-',
            c.phone or '-',
        ])

    filename = f"candidate_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    return Response(
        output.getvalue(),
        mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename={filename}'}
    )