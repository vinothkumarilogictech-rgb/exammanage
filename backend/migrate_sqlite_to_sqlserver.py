import sqlite3
import pyodbc
import re

# =========================
# CONFIGURATION
# =========================

SQLITE_DB = "flask_erp.db"

# CHANGE THESE 3 VALUES
SQL_SERVER = r"vinothkumar\SQLEXPRESS"
SQL_DATABASE = "exam"

WINDOWS_AUTH = False

SQL_USERNAME = "ilt"
SQL_PASSWORD = "ilt"

# =========================
# SQLITE → SQL SERVER TYPES
# =========================

def convert_type(sqlite_type):
    t = (sqlite_type or "").upper()

    if "INT" in t:
        return "INT"

    if "CHAR" in t or "CLOB" in t or "TEXT" in t:
        return "NVARCHAR(MAX)"

    if "REAL" in t or "FLOA" in t or "DOUB" in t:
        return "FLOAT"

    if "DECIMAL" in t or "NUMERIC" in t:
        return "DECIMAL(18, 4)"

    if "BOOL" in t:
        return "BIT"

    if "DATE" in t or "TIME" in t:
        return "DATETIME2"

    if "BLOB" in t:
        return "VARBINARY(MAX)"

    return "NVARCHAR(MAX)"


# =========================
# SQL SERVER CONNECTION
# =========================

def get_sqlserver_connection():
    if WINDOWS_AUTH:
        connection_string = (
            "DRIVER={ODBC Driver 17 for SQL Server};"
            f"SERVER={SQL_SERVER};"
            f"DATABASE={SQL_DATABASE};"
            "Trusted_Connection=yes;"
            "TrustServerCertificate=yes;"
        )
    else:
        connection_string = (
            "DRIVER={ODBC Driver 17 for SQL Server};"
            f"SERVER={SQL_SERVER};"
            f"DATABASE={SQL_DATABASE};"
            f"UID={SQL_USERNAME};"
            f"PWD={SQL_PASSWORD};"
            "TrustServerCertificate=yes;"
        )

    return pyodbc.connect(connection_string)


# =========================
# MAIN MIGRATION
# =========================

def main():

    print("=" * 60)
    print("SQLite → SQL Server Migration")
    print("=" * 60)

    # SQLite
    sqlite_conn = sqlite3.connect(SQLITE_DB)
    sqlite_conn.execute("PRAGMA foreign_keys = OFF")

    sqlite_cursor = sqlite_conn.cursor()

    # SQL Server
    sql_conn = get_sqlserver_connection()
    sql_cursor = sql_conn.cursor()

    print("\nConnected to SQL Server successfully.")

    # Get tables
    tables = sqlite_cursor.execute("""
        SELECT name
        FROM sqlite_master
        WHERE type='table'
        AND name NOT LIKE 'sqlite_%'
        ORDER BY name
    """).fetchall()

    print(f"\nFound {len(tables)} tables.")

    # Disable foreign keys
    try:
        sql_cursor.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'")
        sql_conn.commit()
    except Exception:
        pass

    # =========================
    # CREATE TABLES
    # =========================

    for (table_name,) in tables:

        print(f"\nCreating table: {table_name}")

        columns = sqlite_cursor.execute(
            f'PRAGMA table_info("{table_name}")'
        ).fetchall()

        column_definitions = []

        primary_keys = []

        for col in columns:
            cid, name, col_type, not_null, default_value, pk = col

            sql_type = convert_type(col_type)

            definition = f"[{name}] {sql_type}"

            if pk:
                primary_keys.append(name)

            if not_null:
                definition += " NOT NULL"

            column_definitions.append(definition)

        if primary_keys:
            pk_columns = ", ".join(f"[{x}]" for x in primary_keys)
            column_definitions.append(
                f"PRIMARY KEY ({pk_columns})"
            )

        create_sql = f"""
        IF OBJECT_ID(N'{table_name}', N'U') IS NULL
        BEGIN
            CREATE TABLE [{table_name}] (
                {", ".join(column_definitions)}
            )
        END
        """

        try:
            sql_cursor.execute(create_sql)
            sql_conn.commit()
            print(f"  ✓ {table_name} created")
        except Exception as e:
            print(f"  ✗ Failed creating {table_name}")
            print("   ", e)

    # =========================
    # INSERT DATA
    # =========================

    print("\n")
    print("=" * 60)
    print("Copying data...")
    print("=" * 60)

    for (table_name,) in tables:

        columns = sqlite_cursor.execute(
            f'PRAGMA table_info("{table_name}")'
        ).fetchall()

        column_names = [col[1] for col in columns]

        rows = sqlite_cursor.execute(
            f'SELECT * FROM "{table_name}"'
        ).fetchall()

        if not rows:
            print(f"{table_name}: no data")
            continue

        column_list = ", ".join(
            f"[{x}]" for x in column_names
        )

        placeholders = ", ".join(
            "?" for _ in column_names
        )

        insert_sql = f"""
        INSERT INTO [{table_name}]
        ({column_list})
        VALUES ({placeholders})
        """

        try:
            # Clear existing data
            sql_cursor.execute(
                f"DELETE FROM [{table_name}]"
            )

            sql_cursor.fast_executemany = True
            sql_cursor.executemany(
                insert_sql,
                rows
            )

            sql_conn.commit()

            print(
                f"{table_name}: "
                f"{len(rows)} rows copied ✓"
            )

        except Exception as e:
            sql_conn.rollback()

            print(
                f"{table_name}: FAILED ✗"
            )

            print("   ", e)

    # =========================
    # ENABLE FOREIGN KEYS
    # =========================

    try:
        sql_cursor.execute(
            "EXEC sp_MSforeachtable "
            "'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL'"
        )
        sql_conn.commit()
    except Exception:
        pass

    sqlite_conn.close()
    sql_conn.close()

    print("\n")
    print("=" * 60)
    print("MIGRATION COMPLETED")
    print("=" * 60)


if __name__ == "__main__":
    main()