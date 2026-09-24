"""
One-off fix: adds the missing branch_id column to the exam_team table
in flask_erp.db, so each Team can be scoped to a single branch instead
of showing up on every branch.

Run this once from the backend folder:
    python fix_team_branch_column.py
"""
import os
import sqlite3

db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'flask_erp.db')

if not os.path.exists(db_path):
    print(f"Could not find database at: {db_path}")
    raise SystemExit(1)

conn = sqlite3.connect(db_path)
try:
    cursor = conn.execute("PRAGMA table_info(exam_team)")
    columns = {row[1] for row in cursor.fetchall()}

    migrations = {
        "branch_id": "INTEGER REFERENCES branch(id)",
    }

    added = []
    for column_name, column_type in migrations.items():
        if column_name not in columns:
            conn.execute(f"ALTER TABLE exam_team ADD COLUMN {column_name} {column_type}")
            added.append(column_name)

    conn.commit()

    if added:
        print(f"Added columns: {', '.join(added)}")
    else:
        print("All columns already present — nothing to do.")

    cursor = conn.execute("PRAGMA table_info(exam_team)")
    print("exam_team table columns now:", [row[1] for row in cursor.fetchall()])

    cursor = conn.execute("SELECT COUNT(*) FROM exam_team WHERE branch_id IS NULL")
    unassigned = cursor.fetchone()[0]
    if unassigned:
        print(
            f"\nNote: {unassigned} existing team(s) have no branch assigned yet. "
            "They won't show up under any specific branch until you edit each one "
            "in the app and set its branch."
        )
finally:
    conn.close()
