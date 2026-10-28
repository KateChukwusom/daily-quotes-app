import sqlite3

DB_PATH = "scripts/storage.db"

connection = sqlite3.connect(DB_PATH)
cur = connection.cursor()

# USERS
cur.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    status TEXT DEFAULT 'active',
    frequency TEXT DEFAULT 'daily'
)
""")

# QUOTES
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
    status TEXT,
    UNIQUE(email, sent_date)
)
""")


import csv

with open("users.csv", newline="") as f:
    users = [(r["name"], r["email"], r.get("status", "active"), r.get("frequency", "daily"))
             for r in csv.DictReader(f)]

cur.executemany("""
INSERT OR IGNORE INTO users (name, email, status, frequency)
VALUES (?, ?, ?, ?)
""", users)

connection.commit()
connection.close()

print("Database initialized safely")
