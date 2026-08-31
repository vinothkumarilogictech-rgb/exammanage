import sqlite3

conn = sqlite3.connect("flask_erp.db")
cursor = conn.cursor()

cursor.execute("""
    SELECT id, candidate_id, exam_type_id, branch_id,
           attempt_number, original_scheduled_date,
           scheduled_date, actual_exam_date,
           status, result, cancellation_reason,
           reschedule_reason, remarks
    FROM exam_attempt
    ORDER BY id
""")

rows = cursor.fetchall()

print("\nSQLite exam_attempt")
print("=" * 120)

for row in rows:
    print(row)

print("=" * 120)
print("Total:", len(rows))

conn.close()