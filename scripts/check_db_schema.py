import sqlite3

con = sqlite3.connect(r'd:\CSE AIML\Rashkar\cropnet_dev.db')
cur = con.cursor()
cur.execute("SELECT name, sql FROM sqlite_master WHERE type='table';")
for row in cur.fetchall():
    print("TABLE:", row[0])
    print(row[1])
    print("-" * 50)
