from collections import OrderedDict
from datetime import date
from flask import Blueprint, render_template, session
from apps.models import ExamType, ExamSession, Candidate, ExamAttempt, SessionCandidate, BranchExam, Branch

exams_dashboard_bp = Blueprint('exams_dashboard', __name__, url_prefix='/exams')


def _active_seats_taken(exam_session):
    """Seats on this session currently held by non-cancelled candidates."""
    return sum(
        1 for sc in exam_session.session_candidates
        if sc.candidate and sc.candidate.status != 'Cancelled'
    )


def _months_back(anchor, count):
    """Return `count` (year, month) tuples ending at `anchor`, oldest first, dependency-free."""
    months = []
    y, m = anchor.year, anchor.month
    for _ in range(count):
        months.append((y, m))
        m -= 1
        if m == 0:
            m = 12
            y -= 1
    return list(reversed(months))


@exams_dashboard_bp.route('/')
def dashboard():
    active_branch_id = session.get('active_branch_id')

    # --- Attempt-driven stats ---------------------------------------------
    # Every dashboard count below (and the calendar further down) reads from
    # ExamAttempt - the permanent, per-attempt record of exam activity - so
    # a status change made anywhere in the Exam Management module is
    # reflected here instantly, retests are counted independently of the
    # attempt(s) that came before them, and nothing is derived by merely
    # comparing today's date to a scheduled date.
    attempt_query = ExamAttempt.query
    if active_branch_id:
        attempt_query = attempt_query.filter(ExamAttempt.branch_id == int(active_branch_id))
    attempts = attempt_query.all()

    scheduled_count = sum(1 for a in attempts if a.status == 'Scheduled')
    completed_count = sum(1 for a in attempts if a.status == 'Completed')
    cancelled_count = sum(1 for a in attempts if a.status == 'Cancelled')
    no_show_count = sum(1 for a in attempts if a.status == 'No Show')
    rescheduled_count = sum(1 for a in attempts if a.was_rescheduled)
    retake_count = sum(1 for a in attempts if a.attempt_number > 1)

    if active_branch_id:
        # A candidate "belongs" to a branch (for this branch filter) if any
        # of their attempts were taken at that branch.
        candidate_ids = {a.candidate_id for a in attempts}
        total_candidates = len(candidate_ids)
    else:
        total_candidates = Candidate.query.count()

    # --- Session-driven stats (actual configured sessions, not candidate counts) ---
    session_query = ExamSession.query
    if active_branch_id:
        session_query = session_query.join(BranchExam).filter(BranchExam.branch_id == int(active_branch_id))
    sessions = session_query.all()

    stats = {
        'total_exams': ExamType.query.count(),
        'scheduled': scheduled_count,
        'completed': completed_count,
        'rescheduled': rescheduled_count,
        'cancelled': cancelled_count,
        'no_show': no_show_count,
        'retakes': retake_count,
        'total_sessions': len(sessions),
        'total_candidates': total_candidates,
        'available_seats': sum(
            max(0, (s.seat_capacity or 0) - _active_seats_taken(s))
            for s in sessions if s.status != 'Cancelled'
        ),
        # Explicitly-completed attempts only (BRD #22/#23) - never inferred
        # from a scheduled date being in the past.
        'completed_candidates': completed_count,
    }

    # Upcoming sessions (unrelated to the Exam Activity Calendar below,
    # which is attempt-driven; kept exactly as before).
    upcoming_query = ExamSession.query.filter(ExamSession.status.in_(['Scheduled', 'Rescheduled']))
    if active_branch_id:
        upcoming_query = upcoming_query.join(BranchExam).filter(BranchExam.branch_id == int(active_branch_id))
    upcoming = upcoming_query.order_by(ExamSession.exam_date.asc()).limit(8).all()

    # --- Exam Activity Calendar data ---------------------------------------
    # Each attempt contributes to the calendar on one or two dates:
    #   - Scheduled  -> counted on its (current) scheduled_date
    #   - Completed  -> counted on its actual_exam_date (falls back to
    #                   scheduled_date if somehow missing)
    #   - Cancelled  -> counted on its scheduled_date
    #   - No Show    -> counted on its scheduled_date
    #   - Rescheduled -> in addition to the above, if the attempt has ever
    #                    been moved (original_scheduled_date != current
    #                    scheduled_date) the *original* date keeps a
    #                    permanent "Rescheduled" marker, so that history is
    #                    never lost even though the attempt is now active
    #                    again on its new date.
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
        upcoming=upcoming,
        calendar_attempts=calendar_attempts,
    )


@exams_dashboard_bp.route('/reports')
def reports():
    # Build the last 6 months (oldest -> newest) as buckets for the cancellation trend.
    today = date.today().replace(day=1)
    months = _months_back(today, 6)
    month_names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    buckets = OrderedDict()
    for (y, m) in months:
        buckets[(y, m)] = {'label': f"{month_names[m - 1]} {y}", 'count': 0}

    cancelled_sessions = ExamSession.query.filter(ExamSession.status == 'Cancelled',
                                                    ExamSession.cancelled_at.isnot(None)).all()
    for s in cancelled_sessions:
        key = (s.cancelled_at.year, s.cancelled_at.month)
        if key in buckets:
            buckets[key]['count'] += 1

    trend = list(buckets.values())
    max_count = max((row['count'] for row in trend), default=0) or 1

    total_sessions = ExamSession.query.count()
    total_cancelled = ExamSession.query.filter_by(status='Cancelled').count()

    return render_template('exam_reports.html', trend=trend, max_count=max_count,
                            total_sessions=total_sessions, total_cancelled=total_cancelled)