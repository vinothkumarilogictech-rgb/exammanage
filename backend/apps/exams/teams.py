from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from apps.models import db, ExamTeam, Branch, ExamType, Candidate

teams_bp = Blueprint('teams', __name__, url_prefix='/exams/teams')


@teams_bp.route('/')
def list_teams():
    search = (request.args.get('q') or '').strip()
    status_filter = (request.args.get('status') or '').strip()
    branch_filter = (request.args.get('branch_id') or '').strip()
    exam_type_filter = (request.args.get('exam_type_id') or '').strip()

    query = ExamTeam.query

    if search:
        like = f"%{search}%"
        query = query.filter(
            db.or_(
                ExamTeam.name.ilike(like),
                ExamTeam.location.ilike(like),
                ExamTeam.phone.ilike(like)
            )
        )
    if status_filter and status_filter != 'All':
        query = query.filter(ExamTeam.status == status_filter)
    if branch_filter:
        query = query.filter(ExamTeam.branch_id == int(branch_filter))
    if exam_type_filter:
        query = query.filter(ExamTeam.exam_type_id == int(exam_type_filter))

    active_branch_id = session.get('active_branch_id')
    if active_branch_id and not branch_filter:
        query = query.filter(ExamTeam.branch_id == int(active_branch_id))

    teams = query.order_by(ExamTeam.name.asc()).all()
    branches = Branch.query.order_by(Branch.name.asc()).all()
    exam_types = ExamType.query.order_by(ExamType.name.asc()).all()

    return render_template(
        'exam_teams.html',
        teams=teams,
        branches=branches,
        exam_types=exam_types,
        search=search,
        status_filter=status_filter,
        branch_filter=branch_filter,
        exam_type_filter=exam_type_filter
    )


@teams_bp.route('/save', methods=['POST'])
def save_team():
    team_id = request.form.get('id')
    name = (request.form.get('name') or '').strip()
    location = (request.form.get('location') or '').strip() or None
    phone = (request.form.get('phone') or '').strip() or None
    branch_id = request.form.get('branch_id')
    exam_type_id = request.form.get('exam_type_id')
    status = request.form.get('status') or 'Active'

    next_url = request.form.get('next') or url_for('teams.list_teams')

    if not name:
        flash('Team name is required.', 'error')
        return redirect(next_url)

    if not branch_id:
        flash('Branch is required.', 'error')
        return redirect(next_url)

    try:
        bid = int(branch_id)
    except ValueError:
        flash('Invalid branch.', 'error')
        return redirect(next_url)

    eid = int(exam_type_id) if exam_type_id and exam_type_id.isdigit() else None

    if team_id:
        team = ExamTeam.query.get_or_404(int(team_id))
        team.name = name
        team.location = location
        team.phone = phone
        team.branch_id = bid
        team.exam_type_id = eid
        team.status = status
        db.session.commit()
        flash(f'Team "{name}" updated successfully.', 'success')
    else:
        team = ExamTeam(
            name=name,
            location=location,
            phone=phone,
            branch_id=bid,
            exam_type_id=eid,
            status=status
        )
        db.session.add(team)
        db.session.commit()
        flash(f'Team "{name}" created successfully.', 'success')

    return redirect(next_url)


@teams_bp.route('/<int:team_id>/toggle-status', methods=['POST'])
def toggle_status(team_id):
    team = ExamTeam.query.get_or_404(team_id)
    team.status = 'Inactive' if team.status == 'Active' else 'Active'
    db.session.commit()
    flash(f'Team "{team.name}" status changed to {team.status}.', 'success')
    return redirect(request.form.get('next') or url_for('teams.list_teams'))
