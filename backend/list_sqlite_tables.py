import sqlite3

DB = "flask_erp.db"

conn = sqlite3.connect(DB)

print("\nSQLite Database:", DB)
print("=" * 60)

tables = conn.execute("""
    SELECT name
    FROM sqlite_master
    WHERE type = 'table'
    ORDER BY name
""").fetchall()

for table in tables:
    print(table[0])

print("=" * 60)
print("Total tables:", len(tables))

conn.close()