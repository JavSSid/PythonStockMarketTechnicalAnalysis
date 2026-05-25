import os
import sys
from pathlib import Path
from dotenv import load_dotenv
import psycopg2

load_dotenv(Path(__file__).parent.parent / "config" / ".env")

SQL_DIR = Path(__file__).parent.parent / "sql"

def run_sql_files(conn, subdir: str, label: str):
    cur = conn.cursor()
    sql_path = SQL_DIR / subdir
    files = sorted(sql_path.glob("*.sql"))
    print(f"\n{'='*60}")
    print(f"Running {label} SQL files from {sql_path}")
    print(f"{'='*60}")
    for f in files:
        print(f"  Executing {f.name}...")
        sql = f.read_text()
        try:
            cur.execute(sql)
            conn.commit()
            print(f"  [OK] {f.name}")
        except Exception as e:
            conn.rollback()
            print(f"  [FAIL] {f.name}: {e}")
            raise

def main():
    conn = psycopg2.connect(
        host=os.getenv("STOCK_DB_HOST", "localhost"),
        port=os.getenv("STOCK_DB_PORT", "5432"),
        dbname=os.getenv("STOCK_DB_NAME", "sp500_db"),
        user=os.getenv("STOCK_DB_USER", "postgres"),
        password=os.getenv("STOCK_DB_PASSWORD", "babyLEMON"),
    )
    conn.autocommit = False

    run_sql_files(conn, "setup", "Setup (schemas)")
    run_sql_files(conn, "silver", "Silver layer")
    run_sql_files(conn, "gold", "Gold layer")

    conn.close()
    print("\n✓ Backfill complete!")

if __name__ == "__main__":
    main()
