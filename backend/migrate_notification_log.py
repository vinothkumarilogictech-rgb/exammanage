"""
One-time migration script:
Adds the 'slot' column support by recreating the
payment_notification_log table (log data only, safe to reset).

Run this ONCE from the backend/ folder:
    python migrate_notification_log.py
"""

from apps import create_app
from apps.models import db

app = create_app()

with app.app_context():
    table = db.metadata.tables.get('payment_notification_log')
    if table is not None:
        table.drop(db.engine, checkfirst=True)
        print("Dropped old payment_notification_log table.")
    else:
        print("Table not found in metadata (will be created fresh).")

    db.create_all()
    print("Recreated all tables (payment_notification_log now has 'slot' column).")

print("Migration complete.")