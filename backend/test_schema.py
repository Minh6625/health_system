import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv('DATABASE_URL')
conn = psycopg2.connect(DATABASE_URL)
with conn.cursor() as cur:
    cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name='alerts'")
    rows = cur.fetchall()
    print('Columns in alerts table:', [r[0] for r in rows])
