"""
Standalone fix for the missing voucher_sale_history.paid_amount column on
SQL Server. Unlike the automatic migration in apps/__init__.py (which swallows
errors so the app can still start), this script prints the real error if
anything goes wrong, so we can see exactly why the column isn't there.

Uses the same connection settings as apps/__init__.py (DB_SERVER, DB_DATABASE,
DB_DRIVER env vars, falling back to the same defaults). Run it from the
backend folder:

    python fix_voucher_paid_amount_mssql.py
"""
import os
import sys

try:
    import pyodbc
except ImportError:
    print("pyodbc is not installed in this Python environment.")
    print("Run: pip install pyodbc")
    sys.exit(1)

sql_server = os.environ.get('DB_SERVER', r"vinothkumar\SQLEXPRESS")
sql_database = os.environ.get('DB_DATABASE', "exam")
sql_driver = os.environ.get('DB_DRIVER', "ODBC Driver 17 for SQL Server")

connection_string = (
    f"DRIVER={{{sql_driver}}};"
    f"SERVER={sql_server};"
    f"DATABASE={sql_database};"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

print(f"Connecting to SERVER={sql_server} DATABASE={sql_database} DRIVER={sql_driver} ...")

try:
    conn = pyodbc.connect(connection_string, autocommit=False)
except Exception as e:
    print("FAILED to connect to SQL Server.")
    print(f"Error: {e}")
    print("\nIf DB_SERVER / DB_DATABASE / DB_DRIVER env vars are set differently")
    print("for your running app, set the same env vars before running this script,")
    print("e.g. (PowerShell):  $env:DB_SERVER='yourserver'; $env:DB_DATABASE='yourdb'")
    sys.exit(1)

cursor = conn.cursor()

try:
    cursor.execute("""
        SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'voucher_sale_history' AND COLUMN_NAME = 'paid_amount'
    """)
    exists = cursor.fetchone()[0] > 0

    if exists:
        print("Column 'paid_amount' already exists on voucher_sale_history. Nothing to do.")
    else:
        print("Column missing. Adding it now...")
        cursor.execute(
            "ALTER TABLE voucher_sale_history ADD paid_amount FLOAT NOT NULL DEFAULT 0"
        )
        conn.commit()
        print("Added column 'paid_amount'.")

        print("Backfilling paid_amount = final_amount for rows already marked 'Paid'...")
        cursor.execute(
            "UPDATE voucher_sale_history SET paid_amount = final_amount WHERE payment_status = 'Paid'"
        )
        conn.commit()
        print(f"Backfilled {cursor.rowcount} row(s).")
        print("\nNOTE: existing 'Partial' rows are left at paid_amount = 0, since the")
        print("      amount actually paid so far was never recorded before this column")
        print("      existed. Review/correct those manually if needed.")

    # Confirm the column is really there now.
    cursor.execute("""
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'voucher_sale_history'
        ORDER BY ORDINAL_POSITION
    """)
    print("\nvoucher_sale_history columns now:")
    for row in cursor.fetchall():
        print(f"  - {row.COLUMN_NAME} ({row.DATA_TYPE}, nullable={row.IS_NULLABLE})")

except Exception as e:
    conn.rollback()
    print("\nFAILED while altering/checking the table.")
    print(f"Error: {e}")
    print("\nCommon causes: your Windows login doesn't have ALTER permission on")
    print("this database/table, or DB_SERVER/DB_DATABASE point to a different")
    print("database than the one the Flask app is actually using.")
    sys.exit(1)
finally:
    conn.close()

print("\nDone. Restart the Flask app now.")