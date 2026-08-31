from flask import Blueprint, render_template, request, redirect, url_for, flash
from apps.models import db, Branch, ExamType, BranchExam
from apps.exams.audit import log_action

branch_exams_bp = Blueprint('branch_exams', __name__, url_prefix='/exams/branch-exams')


@branch_exams_bp.route('/')
def list_branch_exams():
    query = BranchExam.query.join(Branch).join(ExamType)

    branch_id = request.args.get('branch_id', '').strip()
    exam_type_id = request.args.get('exam_type_id', '').strip()
    status = request.args.get('status', '').strip()

    if branch_id:
        query = query.filter(BranchExam.branch_id == int(branch_id))
    if exam_type_id:
        query = query.filter(BranchExam.exam_type_id == int(exam_type_id))
    if status:
        query = query.filter(BranchExam.status == status)

    mappings = query.order_by(BranchExam.id.desc()).all()
    branches = Branch.query.order_by(Branch.name).all()
    exam_types = ExamType.query.filter_by(status='Active').order_by(ExamType.name).all()
    return render_template('branch_exams.html', mappings=mappings, branches=branches,
                            exam_types=exam_types, branch_id=branch_id,
                            exam_type_id=exam_type_id, status=status)


@branch_exams_bp.route('/save', methods=['POST'])
def save_mapping():
    branch_id = request.form.get('branch_id')
    exam_type_id = request.form.get('exam_type_id')

    if not branch_id or not exam_type_id:
        flash('Branch and Exam are required.', 'error')
        return redirect(url_for('branch_exams.list_branch_exams'))

    existing = BranchExam.query.filter_by(branch_id=int(branch_id), exam_type_id=int(exam_type_id)).first()
    if existing:
        flash('This exam is already mapped to the selected branch.', 'error')
        return redirect(url_for('branch_exams.list_branch_exams'))

    mapping = BranchExam(branch_id=int(branch_id), exam_type_id=int(exam_type_id), status='Active')
    db.session.add(mapping)
    db.session.flush()
    log_action('Branch Exam Mapping Created', record_id=mapping.id,
                new_value=f"branch={mapping.branch.name}, exam={mapping.exam_type.name}")
    db.session.commit()
    return redirect(url_for('branch_exams.list_branch_exams'))


@branch_exams_bp.route('/<int:mapping_id>/toggle-status', methods=['POST'])
def toggle_mapping_status(mapping_id):
    mapping = BranchExam.query.get_or_404(mapping_id)
    old_status = mapping.status
    mapping.status = 'Inactive' if mapping.status == 'Active' else 'Active'
    log_action('Status Changed', record_id=mapping.id, old_value=old_status, new_value=mapping.status)
    db.session.commit()
    return redirect(url_for('branch_exams.list_branch_exams'))


# ---- Branch master (minimal, required to support Branch <-> Exam mapping) ----

@branch_exams_bp.route('/branches')
def list_branches():
    branches = Branch.query.order_by(Branch.id.desc()).all()
    return render_template('branches.html', branches=branches)


@branch_exams_bp.route('/branches/save', methods=['POST'])
def save_branch():
    branch_id = request.form.get('id')
    name = (request.form.get('name') or '').strip()
    location = (request.form.get('location') or '').strip()
    status = request.form.get('status') or 'Active'

    if not name:
        flash('Branch name is required.', 'error')
        return redirect(url_for('branch_exams.list_branches'))

    if branch_id:
        branch = Branch.query.get_or_404(int(branch_id))
        branch.name = name
        branch.location = location
        branch.status = status
    else:
        db.session.add(Branch(name=name, location=location, status=status))
    db.session.commit()
    return redirect(url_for('branch_exams.list_branches'))


@branch_exams_bp.route('/branches/<int:branch_id>/toggle-status', methods=['POST'])
def toggle_branch_status(branch_id):
    branch = Branch.query.get_or_404(branch_id)
    branch.status = 'Inactive' if branch.status == 'Active' else 'Active'
    db.session.commit()
    return redirect(url_for('branch_exams.list_branches'))
