import sqlite3

DB = "flask_erp.db"

conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row

print("\nSQLite branch table")
print("=" * 100)

columns = conn.execute("PRAGMA table_info(branch)").fetchall()

print("\nColumns:")
for col in columns:
    print(f"{col['name']} | type={col['type']} | nullable={not col['notnull']}")

print("\nData:")
print("=" * 100)

rows = conn.execute("SELECT * FROM branch ORDER BY id").fetchall()

for row in rows:
    print(dict(row))

print("=" * 100)
print("Total branches:", len(rows))

conn.close()