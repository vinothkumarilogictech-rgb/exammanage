import sqlite3
import pyodbc

print("=" * 60)
print("SQL SERVER")
print("=" * 60)

conn = pyodbc.connect(
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=vinothkumar\\SQLEXPRESS;"
    "DATABASE=exam;"
    "Trusted_Connection=yes;"
)

cur = conn.cursor()

cur.execute("SELECT COUNT(*) FROM dbo.branch")
print("SQL Server branch count:", cur.fetchone()[0])

cur.execute("""
    SELECT id, branch_name
    FROM dbo.branch
    ORDER BY id
""")

for row in cur.fetchall():
    print(row)

conn.close()

print()
print("=" * 60)
print("SQLITE")
print("=" * 60)

conn = sqlite3.connect("flask_erp.db")
cur = conn.cursor()

cur.execute("SELECT COUNT(*) FROM branch")
print("SQLite branch count:", cur.fetchone()[0])

cur.execute("""
    SELECT id, branch_name
    FROM branch
    ORDER BY id
""")

for row in cur.fetchall():
    print(row)

conn.close()