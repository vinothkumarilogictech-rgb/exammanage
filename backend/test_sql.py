import os
import pyodbc
from dotenv import load_dotenv

load_dotenv(override=True)

server = os.getenv("DB_SERVER")
database = os.getenv("DB_DATABASE")
driver = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server")
trusted = os.getenv("DB_TRUSTED_CONNECTION", "yes")

print("Server   :", server)
print("Database :", database)
print("Driver   :", driver)
print("Trusted  :", trusted)

connection_string = (
    f"DRIVER={{{driver}}};"
    f"SERVER={server};"
    f"DATABASE={database};"
    "Trusted_Connection=yes;"
)

try:
    conn = pyodbc.connect(connection_string, timeout=5)

    cursor = conn.cursor()

    cursor.execute("SELECT DB_NAME()")
    db_name = cursor.fetchone()[0]

    print()
    print("========================================")
    print("SQL SERVER CONNECTED SUCCESSFULLY")
    print("Database:", db_name)
    print("========================================")

    cursor.execute("SELECT COUNT(*) FROM dbo.exam_attempt")
    count = cursor.fetchone()[0]

    print("exam_attempt rows:", count)

    cursor.close()
    conn.close()

except Exception as e:
    print()
    print("SQL SERVER CONNECTION FAILED")
    print("----------------------------------------")
    print(e)