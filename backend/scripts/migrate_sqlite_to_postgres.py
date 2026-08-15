"""Replace application data in PostgreSQL with a SQLite development snapshot.

Authentication sessions and password-reset codes are intentionally not copied;
they are ephemeral security state and should never be promoted between environments.
"""

import argparse
import os
import sqlite3

import psycopg
from sqlalchemy.engine import make_url


TABLES = [
    "users",
    "newsletters",
    "issues",
    "issue_images",
    "replies",
    "subscriptions",
    "newsletter_invitations",
    "friend_requests",
]


def target_dsn() -> str:
    parsed = make_url(os.environ["DATABASE_URL"])
    return psycopg.conninfo.make_conninfo(
        host=parsed.host,
        port=parsed.port,
        dbname=parsed.database,
        user=parsed.username,
        password=parsed.password,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    args = parser.parse_args()

    source = sqlite3.connect(args.source)
    source.row_factory = sqlite3.Row
    try:
        with psycopg.connect(target_dsn()) as target:
            with target.cursor() as cursor:
                cursor.execute(
                    "TRUNCATE TABLE newsletter_invitations, friend_requests, subscriptions, "
                    "replies, issue_images, issues, newsletters, users RESTART IDENTITY CASCADE"
                )
                for table in TABLES:
                    columns = [row[1] for row in source.execute(f"PRAGMA table_info({table})")]
                    rows = source.execute(f"SELECT {', '.join(columns)} FROM {table}").fetchall()
                    if not rows:
                        continue
                    quoted = ", ".join(f'"{column}"' for column in columns)
                    placeholders = ", ".join(["%s"] * len(columns))
                    cursor.executemany(
                        f'INSERT INTO "{table}" ({quoted}) VALUES ({placeholders})',
                        [tuple(row[column] for column in columns) for row in rows],
                    )
                for table in TABLES:
                    cursor.execute(
                        f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), "
                        f"COALESCE((SELECT MAX(id) FROM {table}), 1), true)"
                    )
            target.commit()
    finally:
        source.close()


if __name__ == "__main__":
    main()
