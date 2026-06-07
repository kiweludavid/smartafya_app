import sqlite3
from pathlib import Path


def main() -> None:
    db_path = Path(__file__).resolve().parents[1] / "smart_afya.db"
    if not db_path.exists():
        raise SystemExit(f"DB not found at {db_path}")
    con = sqlite3.connect(str(db_path))
    cur = con.cursor()
    cur.execute("UPDATE users SET role='admin', specialist_type=NULL WHERE email=?", ("admin@smartafya.com",))
    con.commit()
    cur.execute("SELECT email, role, specialist_type, is_active FROM users WHERE email=?", ("admin@smartafya.com",))
    print(cur.fetchone())
    con.close()


if __name__ == "__main__":
    main()

