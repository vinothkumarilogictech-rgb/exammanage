from flask import Blueprint, render_template, request, redirect, url_for, flash
from apps.models import db, ExamType
from apps.exams.audit import log_action

exam_types_bp = Blueprint('exam_types', __name__, url_prefix='/exams/types')


@exam_types_bp.route('/')
def list_exam_types():
    query = ExamType.query
    search = request.args.get('q', '').strip()
    language = request.args.get('language', '').strip()
    status = request.args.get('status', '').strip()

    if search:
        query = query.filter(ExamType.name.ilike(f'%{search}%'))
    if language:
        query = query.filter(ExamType.language == language)
    if status:
        query = query.filter(ExamType.status == status)

    exam_types = query.order_by(ExamType.id.desc()).all()
    languages = [row[0] for row in db.session.query(ExamType.language).distinct().all() if row[0]]
    return render_template('exam_types.html', exam_types=exam_types, languages=languages,
                            search=search, language=language, status=status)


@exam_types_bp.route('/save', methods=['POST'])
def save_exam_type():
    exam_type_id = request.form.get('id')
    name = (request.form.get('name') or '').strip()
    language = (request.form.get('language') or '').strip()
    description = (request.form.get('description') or '').strip()
    status = request.form.get('status') or 'Active'

    if not name or not language:
        flash('Exam name and language are required.', 'error')
        return redirect(url_for('exam_types.list_exam_types'))

    if exam_type_id:
        exam_type = ExamType.query.get_or_404(int(exam_type_id))
        old_value = f"{exam_type.name} | {exam_type.language} | {exam_type.status}"
        exam_type.name = name
        exam_type.language = language
        exam_type.description = description
        exam_type.status = status
        db.session.flush()
        log_action('Exam Updated', record_id=exam_type.id, old_value=old_value,
                    new_value=f"{name} | {language} | {status}")
    else:
        exam_type = ExamType(name=name, language=language, description=description, status=status)
        db.session.add(exam_type)
        db.session.flush()
        log_action('Exam Created', record_id=exam_type.id, new_value=f"{name} | {language} | {status}")

    db.session.commit()
    return redirect(url_for('exam_types.list_exam_types'))


@exam_types_bp.route('/<int:exam_type_id>/toggle-status', methods=['POST'])
def toggle_status(exam_type_id):
    exam_type = ExamType.query.get_or_404(exam_type_id)
    old_status = exam_type.status
    exam_type.status = 'Inactive' if exam_type.status == 'Active' else 'Active'
    log_action('Status Changed', record_id=exam_type.id, old_value=old_status, new_value=exam_type.status)
    db.session.commit()
    return redirect(url_for('exam_types.list_exam_types'))
