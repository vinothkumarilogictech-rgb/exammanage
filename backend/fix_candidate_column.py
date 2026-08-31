"""
One-off fix: adds the missing register_number, test_type, exam_date
columns to the candidate table in flask_erp.db.

Run this once from the Office-Management-main folder:
    python fix_candidate_columns.py
"""
import os
import sqlite3

db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'flask_erp.db')

if not os.path.exists(db_path):
    print(f"Could not find database at: {db_path}")
    raise SystemExit(1)

conn = sqlite3.connect(db_path)
try:
    cursor = conn.execute("PRAGMA table_info(candidate)")
    columns = {row[1] for row in cursor.fetchall()}

    migrations = {
        "register_number": "VARCHAR(100)",
        "test_type": "VARCHAR(100)",
        "exam_date": "VARCHAR(20)",
    }

    added = []
    for column_name, column_type in migrations.items():
        if column_name not in columns:
            conn.execute(f"ALTER TABLE candidate ADD COLUMN {column_name} {column_type}")
            added.append(column_name)

    conn.commit()

    if added:
        print(f"Added columns: {', '.join(added)}")
    else:
        print("All columns already present — nothing to do.")

    cursor = conn.execute("PRAGMA table_info(candidate)")
    print("candidate table columns now:", [row[1] for row in cursor.fetchall()])
finally:
    conn.close()