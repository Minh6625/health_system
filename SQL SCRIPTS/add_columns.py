import os
import psycopg2
from urllib.parse import urlparse

db_url = "postgresql://postgres:88888888@0.tcp.ngrok.io:18304/production"
result = urlparse(db_url)

conn = psycopg2.connect(
    dbname=result.path[1:],
    user=result.username,
    password=result.password,
    host=result.hostname,
    port=result.port
)

cursor = conn.cursor()
try:
    cursor.execute("ALTER TABLE user_relationships ADD COLUMN primary_relationship_label VARCHAR(100);")
    print("Added primary_relationship_label")
except Exception as e:
    print("Error:", e)
    conn.rollback()

try:
    cursor.execute("ALTER TABLE user_relationships ADD COLUMN tags JSONB;")
    print("Added tags")
except Exception as e:
    print("Error:", e)
    conn.rollback()

conn.commit()
cursor.close()
conn.close()
print("Done!")
