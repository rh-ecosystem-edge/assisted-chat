"""
This script connects to a PostgreSQL database and performs migrations.

This is because lightspeed-stack does not currently perform migrations on its own,
which means the database either has to be created from scratch or migrated like we do here.

Any migrations added should be idempotent, meaning they can be ran multiple times without
causing errors or unintended effects. This is because we run this script every time the
service starts to ensure the database is up to date.

Currently the migrations are as follows:

1. Add a new column `topic_summary` as it was added in lightspeed-stack v0.3.0

WARNING: This script assumes that the database is postgres and that the schema used is
called `lightspeed-stack`. If either of these assumptions are incorrect, the script may fail
or cause unintended effects. lightspeed-stack could also use sqlite or a different schema
if configured to do so, but we don't handle those cases here because we don't use them.
"""

import os
import time
import sys

import psycopg2

for _ in range(30):
    try:
        conn = psycopg2.connect(
            host=os.getenv("ASSISTED_CHAT_POSTGRES_HOST"),
            port=os.getenv("ASSISTED_CHAT_POSTGRES_PORT"),
            dbname=os.getenv("ASSISTED_CHAT_POSTGRES_NAME"),
            user=os.getenv("ASSISTED_CHAT_POSTGRES_USER"),
            password=os.getenv("ASSISTED_CHAT_POSTGRES_PASSWORD"),
            sslmode=os.getenv("LIGHTSPEED_STACK_POSTGRES_SSL_MODE"),
        )
        break
    except psycopg2.OperationalError as e:
        print("Waiting for Postgres...", e, file=sys.stderr)
        time.sleep(2)
else:
    sys.exit("Postgres not available after 60s")


# Ensure the schema even exists, if it doesn't, it's a fresh database and
# we don't need to run migrations
with conn.cursor() as cur:
    cur.execute(
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'lightspeed-stack'"
    )
    if not cur.fetchone():
        print(
            "Schema 'lightspeed-stack' absent, database probably fresh, skipping migrations"
        )
        conn.close()
        sys.exit(0)


cur = conn.cursor()
cur.execute(
    'ALTER TABLE "lightspeed-stack"."user_conversation" ADD COLUMN IF NOT EXISTS topic_summary text'
)
conn.commit()
cur.close()
conn.close()
print("Migration completed")
