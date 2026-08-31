import os
import sqlite3

base = r'd:\dhiya\office'
if not os.path.isdir(base):
    print('Workspace folder not found:', base)
    raise SystemExit(1)

files = [f for f in os.listdir(base) if f.startswith('flask_erp')]
if not files:
    print('No files starting with "flask_erp" found in', base)
    print('Files in folder:', os.listdir(base))
    raise SystemExit(0)

for f in files:
    fp = os.path.join(base, f)
    print('\n--- Trying file:', fp)
    if not os.path.isfile(fp):
        print('Not a file')
        continue
    try:
        conn = sqlite3.connect(fp)
        cur = conn.cursor()
        cur.execute("SELECT name, type FROM sqlite_master WHERE type IN ('table','view') ORDER BY name LIMIT 50")
        rows = cur.fetchall()
        if not rows:
            print('Opened but no tables/views found (file may not be a SQLite DB)')
        else:
            print('Found tables/views:')
            for r in rows:
                print(' -', r[0], '(', r[1], ')')
        conn.close()
    except Exception as e:
        print('Error opening as SQLite DB:', e)
