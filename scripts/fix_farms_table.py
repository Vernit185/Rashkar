import sys, os
sys.path.insert(0, os.path.abspath('.'))

import sqlite3
from sqlalchemy import create_engine
from services.api.app.models.soil_and_farm import Base, FarmModel

con = sqlite3.connect('cropnet_dev.db')
cur = con.cursor()
cur.execute("SELECT count(*) FROM farms")
row_count = cur.fetchone()[0]
print("Row count in legacy farms:", row_count)

if row_count == 0:
    print("Dropping legacy empty farms table...")
    cur.execute("DROP TABLE farms;")
    con.commit()
    con.close()
    
    print("Creating farms table from current FarmModel metadata...")
    engine = create_engine("sqlite:///./cropnet_dev.db")
    Base.metadata.create_all(bind=engine)
    
    # Re-verify schema
    con2 = sqlite3.connect('cropnet_dev.db')
    cur2 = con2.cursor()
    cur2.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='farms';")
    print("New farms table schema:")
    print(cur2.fetchone()[0])
    con2.close()
else:
    print("Table has rows, skipping drop")
