
import sqlite3
import csv
import os

#This is to tell ECS where tthe EFS folder is
#stores the database location in DB_PATH
DB_PATH = os.environ.get("DB_PATH", "scripts/storage.db")

connection = sqlite3.connect(DB_PATH)

#Create the cursor to send commands to the database
cur = connection.cursor()

# create tabke called USERS
cur.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    status TEXT DEFAULT 'active',
    frequency TEXT DEFAULT 'daily'
)
""")

# create table called QUOTES
cur.execute("""
CREATE TABLE IF NOT EXISTS quotes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    quote TEXT NOT NULL,
    author TEXT NOT NULL,
    date_fetched TEXT UNIQUE
)
""")

# EMAIL LOGS
cur.execute("""
CREATE TABLE IF NOT EXISTS email_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    sent_date TEXT NOT NULL,
    status TEXT
)
""")

# Allow only ONE 'pending' or 'success' row per person per day.
# 'failed' rows are not limited, so a failed send can be retried.
cur.execute("""
CREATE UNIQUE INDEX IF NOT EXISTS one_send_per_day
ON email_logs (email, sent_date)
WHERE status IN ('pending', 'success')
""")


with open("scripts/users.csv", newline="") as f:
    users = [(r["name"], r["email"], r.get("status", "active"), r.get("frequency", "daily"))
             for r in csv.DictReader(f)]

cur.executemany("""
INSERT OR IGNORE INTO users (name, email, status, frequency)
VALUES (?, ?, ?, ?)
""", users)

connection.commit()
connection.close()

print("Database initialized safely")
