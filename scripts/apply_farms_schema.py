import sqlite3

con = sqlite3.connect('cropnet_dev.db')
cur = con.cursor()

# Check row count
cur.execute("SELECT count(*) FROM farms")
cnt = cur.fetchone()[0]
print(f"Existing rows in farms: {cnt}")

if cnt == 0:
    print("Dropping legacy farms table...")
    cur.execute("DROP TABLE farms")
    
    print("Creating farms table with current schema matching FarmModel...")
    cur.execute("""
    CREATE TABLE farms (
        id VARCHAR(36) NOT NULL,
        owner_id VARCHAR(36) NOT NULL,
        name VARCHAR(100) NOT NULL,
        village VARCHAR(100),
        taluka VARCHAR(100) NOT NULL,
        district VARCHAR(100) NOT NULL DEFAULT 'Pune',
        state VARCHAR(100) NOT NULL DEFAULT 'Maharashtra',
        irrigation_type VARCHAR(50) DEFAULT 'unknown',
        water_source VARCHAR(50) DEFAULT 'unknown',
        geometry_geojson JSON NOT NULL,
        calculated_area_hectares FLOAT NOT NULL,
        calculated_area_acres FLOAT NOT NULL,
        centroid_latitude FLOAT,
        centroid_longitude FLOAT,
        created_at DATETIME,
        updated_at DATETIME,
        PRIMARY KEY (id)
    );
    """)
    cur.execute("CREATE INDEX ix_farms_owner_id ON farms (owner_id);")
    cur.execute("CREATE INDEX ix_farms_taluka ON farms (taluka);")
    con.commit()
    print("Successfully created modern farms table!")

# Verify
cur.execute("PRAGMA table_info(farms)")
columns = [row[1] for row in cur.fetchall()]
print("Columns in farms:", columns)
assert 'id' in columns and 'name' in columns and 'geometry_geojson' in columns
con.close()
