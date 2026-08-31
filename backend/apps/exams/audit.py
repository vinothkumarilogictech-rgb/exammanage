"""Shared helpers for the Exam Management module (audit logging)."""
from apps.models import db, ExamAuditLog


def log_action(action, record_id=None, old_value=None, new_value=None, reason=None, user='Admin'):
    """Persist an audit trail entry for an Exam Management action.

    old_value / new_value should already be plain strings (or None).
    Never raises - a failed audit write should not break the calling transaction,
    but it does get flushed as part of the same session/commit as the caller.
    """
    entry = ExamAuditLog(
        user=user,
        action=action,
        module='Exam Management',
        record_id=record_id,
        old_value=old_value,
        new_value=new_value,
        reason=reason,
    )
    db.session.add(entry)
    return entry
