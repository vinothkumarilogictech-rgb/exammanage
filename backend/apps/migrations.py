import logging
import os
import sys
import traceback
from sqlalchemy import inspect, text

logger = logging.getLogger("db_migrations")
if not logger.handlers:
    stream = sys.stdout if sys.stdout is not None else sys.stderr
    handler = logging.StreamHandler(stream) if stream is not None else logging.NullHandler()
    handler.setFormatter(
        logging.Formatter("[%(asctime)s] [%(levelname)s] [DB_MIGRATION] %(message)s")
    )
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


class DatabaseMigrationError(RuntimeError):
    """Raised when database schema synchronization fails."""
    pass


def _log_fatal_error(app, message, exc=None):
    """Log fatal error to logger, stderr, and migration_error.log for EXE visibility."""
    formatted_msg = f"\n{'='*70}\nCRITICAL DATABASE MIGRATION ERROR:\n{message}\n"
    if exc:
        formatted_msg += f"Exception details: {exc}\n"
        formatted_msg += traceback.format_exc()
    formatted_msg += f"{'='*70}\n"

    logger.critical(formatted_msg)
    if sys.stderr is not None:
        try:
            sys.stderr.write(formatted_msg)
            sys.stderr.flush()
        except Exception:
            pass

    try:
        log_dir = os.path.dirname(os.path.abspath(app.root_path))
        error_file = os.path.join(log_dir, "migration_error.log")
        with open(error_file, "a", encoding="utf-8") as f:
            f.write(formatted_msg)
    except Exception:
        pass


def _format_default_sql(col, dialect_name):
    """
    Extract a safe literal SQL DEFAULT clause from a Column's default definition.
    Returns string like "DEFAULT 'value'" or None if callable or not applicable.
    """
    # 1. Check server_default first
    if col.server_default is not None:
        if hasattr(col.server_default, 'arg') and hasattr(col.server_default.arg, 'text'):
            return f"DEFAULT {col.server_default.arg.text}"
        elif isinstance(col.server_default.arg, str):
            return f"DEFAULT {col.server_default.arg}"

    # 2. Check model-level default (e.g. default='Registered', default=0.0)
    if col.default is not None and hasattr(col.default, 'arg'):
        arg = col.default.arg
        # Callable defaults (like datetime.utcnow) cannot be formatted as SQL literals.
        # SQLAlchemy applies them in Python at insert time anyway.
        if callable(arg):
            return None

        if isinstance(arg, bool):
            return "DEFAULT 1" if arg else "DEFAULT 0"
        elif isinstance(arg, (int, float)):
            return f"DEFAULT {arg}"
        elif isinstance(arg, str):
            escaped = arg.replace("'", "''")
            return f"DEFAULT '{escaped}'"

    return None


def run_additive_migrations(app):
    """
    Synchronizes the existing database schema with current SQLAlchemy models
    using SAFE, IDEMPOTENT, ADDITIVE migrations.

    Startup flow:
    1. Connect to configured database engine (SQL Server, SQLite, etc.)
    2. Inspect existing database schema
    3. Check required tables from SQLAlchemy models
    4. Create ONLY missing tables
    5. Check columns in existing tables
    6. Add ONLY missing columns using model-compiled data types
    7. Perform safe data backfills for new columns where values are NULL
    8. Re-inspect database schema to verify ALL required tables and columns exist
    9. Finish migration -> allow application to start

    SAFETY GUARANTEES:
    - NEVER DROP DATABASE
    - NEVER DROP TABLE
    - NEVER TRUNCATE TABLE
    - NEVER DELETE existing records
    - NEVER Rename existing columns
    - NEVER Replace the old database
    - NEVER Overwrite existing values
    """
    from apps.models import db

    engine = db.engine
    dialect_name = engine.dialect.name
    logger.info("Starting safe additive database migration against dialect '%s'...", dialect_name)

    try:
        # Step 1: Introspect existing schema
        inspector = inspect(engine)
        existing_tables_raw = inspector.get_table_names()
        # Case-insensitive table name mapping: lower_name -> actual_db_name
        existing_tables_map = {t.lower(): t for t in existing_tables_raw}
        logger.info("Found %d existing tables in database.", len(existing_tables_raw))

        # Step 2: Check required tables from SQLAlchemy models & create missing ones
        models_metadata = db.metadata
        created_tables = []
        for table_name, table_obj in models_metadata.tables.items():
            if table_name.lower() not in existing_tables_map:
                logger.info("Missing table detected: '%s'. Creating table safely...", table_name)
                # Create ONLY this table
                table_obj.create(bind=engine, checkfirst=True)
                existing_tables_map[table_name.lower()] = table_name
                created_tables.append(table_name)
                logger.info("Table '%s' created successfully.", table_name)

        if created_tables:
            logger.info("Created %d missing table(s): %s", len(created_tables), created_tables)
            # Refresh inspector after table creation
            inspector = inspect(engine)
            existing_tables_raw = inspector.get_table_names()
            existing_tables_map = {t.lower(): t for t in existing_tables_raw}

        # Step 3: Check columns in existing tables & add missing ones
        added_columns_count = 0
        added_columns_by_table = {}

        for table_name, table_obj in models_metadata.tables.items():
            actual_table_name = existing_tables_map[table_name.lower()]

            # Fetch columns currently in the database
            db_columns = inspector.get_columns(actual_table_name)
            existing_cols_map = {c['name'].lower(): c['name'] for c in db_columns}

            for col in table_obj.columns:
                col_name_lower = col.name.lower()
                if col_name_lower in existing_cols_map:
                    # Column already exists: skip it (IDEMPOTENT)
                    continue

                # Missing column found: compile type directly from model definition
                col_type_sql = col.type.compile(engine.dialect)
                default_sql = _format_default_sql(col, dialect_name)

                logger.info(
                    "Missing column detected: [%s].[%s] (Model type: %s, Default: %s)",
                    actual_table_name, col.name, col_type_sql, default_sql or "None"
                )

                # Build dialect-specific safe ALTER TABLE statement
                if dialect_name == "mssql":
                    if default_sql:
                        alter_stmt = (
                            f"ALTER TABLE [{actual_table_name}] ADD [{col.name}] "
                            f"{col_type_sql} {default_sql} NULL"
                        )
                    else:
                        alter_stmt = (
                            f"ALTER TABLE [{actual_table_name}] ADD [{col.name}] "
                            f"{col_type_sql} NULL"
                        )
                elif dialect_name == "sqlite":
                    if default_sql:
                        alter_stmt = (
                            f'ALTER TABLE "{actual_table_name}" ADD COLUMN "{col.name}" '
                            f"{col_type_sql} {default_sql}"
                        )
                    else:
                        alter_stmt = (
                            f'ALTER TABLE "{actual_table_name}" ADD COLUMN "{col.name}" '
                            f"{col_type_sql}"
                        )
                else:
                    # Generic ANSI SQL fallback
                    if default_sql:
                        alter_stmt = (
                            f'ALTER TABLE "{actual_table_name}" ADD "{col.name}" '
                            f"{col_type_sql} {default_sql} NULL"
                        )
                    else:
                        alter_stmt = (
                            f'ALTER TABLE "{actual_table_name}" ADD "{col.name}" '
                            f"{col_type_sql} NULL"
                        )

                # Execute statement in its own transaction
                logger.info("Executing migration DDL: %s", alter_stmt)
                with engine.begin() as conn:
                    conn.execute(text(alter_stmt))

                added_columns_count += 1
                added_columns_by_table.setdefault(actual_table_name, []).append(col.name)
                logger.info("Added column [%s].[%s] successfully.", actual_table_name, col.name)

        if added_columns_count > 0:
            logger.info(
                "Added %d missing column(s) across %d table(s): %s",
                added_columns_count, len(added_columns_by_table), added_columns_by_table
            )
        else:
            logger.info("All model columns already exist in database tables. No schema changes needed.")

        # Step 4: Safe one-time data backfills for newly added columns
        # (Only affects rows where the new column is NULL; never overwrites existing data)
        with engine.begin() as conn:
            # voucher_sale_history.paid_amount
            if 'voucher_sale_history' in existing_tables_map:
                vsh_table = existing_tables_map['voucher_sale_history']
                try:
                    conn.execute(text(
                        f"UPDATE [{vsh_table}] SET paid_amount = final_amount "
                        f"WHERE payment_status = 'Paid' AND paid_amount IS NULL"
                    ))
                except Exception as bf_err:
                    logger.debug("voucher_sale_history backfill notice: %s", bf_err)

            # expense.paid_amount
            if 'expense' in existing_tables_map:
                exp_table = existing_tables_map['expense']
                try:
                    conn.execute(text(
                        f"UPDATE [{exp_table}] SET paid_amount = amount "
                        f"WHERE paid_amount IS NULL AND amount IS NOT NULL"
                    ))
                except Exception as bf_err:
                    logger.debug("expense backfill notice: %s", bf_err)

        # Step 5: Post-migration re-inspection and verification
        logger.info("Re-inspecting database schema to verify complete synchronization...")
        post_inspector = inspect(engine)
        post_tables_map = {t.lower(): t for t in post_inspector.get_table_names()}

        missing_tables_post = []
        missing_columns_post = []

        for table_name, table_obj in models_metadata.tables.items():
            if table_name.lower() not in post_tables_map:
                missing_tables_post.append(table_name)
                continue

            actual_tbl = post_tables_map[table_name.lower()]
            actual_cols = {c['name'].lower() for c in post_inspector.get_columns(actual_tbl)}

            for col in table_obj.columns:
                if col.name.lower() not in actual_cols:
                    missing_columns_post.append(f"{actual_tbl}.{col.name}")

        if missing_tables_post or missing_columns_post:
            error_details = []
            if missing_tables_post:
                error_details.append(f"Missing tables: {missing_tables_post}")
            if missing_columns_post:
                error_details.append(f"Missing columns: {missing_columns_post}")
            full_err_msg = "Database schema synchronization incomplete! " + "; ".join(error_details)
            _log_fatal_error(app, full_err_msg)
            raise DatabaseMigrationError(full_err_msg)

        logger.info(
            "[MIGRATION SUCCESS] All %d models and all columns verified in database schema. Database is ready.",
            len(models_metadata.tables)
        )

    except DatabaseMigrationError:
        raise
    except Exception as e:
        err_msg = f"Database migration failed during execution: {str(e)}"
        _log_fatal_error(app, err_msg, exc=e)
        raise DatabaseMigrationError(err_msg) from e
