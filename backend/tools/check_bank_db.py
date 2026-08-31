import sqlite3, os

db = r'd:\jose\office\flask_erp.db'
if not os.path.exists(db):
    print('DB not found:', db)
else:
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    try:
        cur.execute('SELECT id, account_name, account_number, opening_balance, current_balance, amount FROM bank ORDER BY id DESC LIMIT 5')
        rows = cur.fetchall()
        if not rows:
            print('No bank rows')
        else:
            for r in rows:
                print(r)
    except Exception as e:
        print('Query error:', e)
    finally:
        conn.close()
