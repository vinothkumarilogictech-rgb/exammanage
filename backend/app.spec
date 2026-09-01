# -*- mode: python ; coding: utf-8 -*-
#
# Build with:  pyinstaller app.spec
# Must be run on Windows (PyInstaller does not cross-compile).
# Run from the project's backend/ folder with your venv activated.

import os

block_cipher = None
project_root = os.path.abspath('.')

a = Analysis(
    ['app.py'],
    pathex=[project_root],
    binaries=[],
    datas=[
        ('templates', 'templates'),
        ('static', 'static'),
        ('.env', '.'),
        # flask_erp.db is only used as a fallback/legacy sqlite source;
        # include it so the ensure_*_columns() sqlite migrations don't
        # error out looking for it next to the exe. Remove this line if
        # you don't want the sqlite file bundled into the exe.
        ('flask_erp.db', '.'),
    ],
    hiddenimports=[
        # pyodbc + the SQL Server SQLAlchemy dialect - not picked up by
        # PyInstaller's static analysis because SQLAlchemy loads dialects
        # dynamically by name.
        'pyodbc',
        'sqlalchemy.dialects.mssql',
        'sqlalchemy.dialects.mssql.pyodbc',
        'sqlalchemy.dialects.mssql.base',

        # Flask/Flask-Login/Flask-SQLAlchemy internals sometimes missed
        'flask_login',
        'flask_sqlalchemy',
        'werkzeug.security',
        'itsdangerous',

        # Blueprint modules imported dynamically inside apps/__init__.py's
        # create_app() - PyInstaller's static analysis won't see these
        # unless they're listed explicitly.
        'apps.branches.routes',
        'apps.expenses.routes',
        'apps.expenses.helpers',
        'apps.vouchers.routes',
        'apps.exams.dashboard',
        'apps.exams.exam_types',
        'apps.exams.branch_exams',
        'apps.exams.sessions',
        'apps.exams.candidates',
        'apps.exams.audit_logs',
        'apps.exams.audit',
        'apps.models',
        'api',
        'api.auth',
        'api.routes',
        'api.views',
        'api.urls',
        'api.apps',
        'api.serializers',
        'api.filters',
        'api.pagination',
        'api.permissions',
        'api.exceptions',

        # Optional export libs referenced at runtime by expense export
        'reportlab',
        'openpyxl',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='ExamERP',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,   # set to False once you've confirmed it works, to hide the console window
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
