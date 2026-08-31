from flask import Blueprint, render_template, request
from apps.models import ExamAuditLog

audit_logs_bp = Blueprint('audit_logs', __name__, url_prefix='/exams/audit-logs')


@audit_logs_bp.route('/')
def list_audit_logs():
    query = ExamAuditLog.query
    action = request.args.get('action', '').strip()
    if action:
        query = query.filter(ExamAuditLog.action == action)

    logs = query.order_by(ExamAuditLog.timestamp.desc()).limit(300).all()
    actions = [row[0] for row in ExamAuditLog.query.with_entities(ExamAuditLog.action).distinct().all()]
    return render_template('audit_logs.html', logs=logs, actions=actions, action=action)
