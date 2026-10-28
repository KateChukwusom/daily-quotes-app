## MindFuel Daily Quote Delivery System
# Project Overview
MindFuel is an automated quote delivery platform designed to fetch an inspiring quote every morning from the ZenQuotes API and send it to subscribers via email at 7:00 AM daily.

The system was built to be:

Reliable: handles failures gracefully and ensures consistency.

Auditable: keeps clear logs of every process and email sent.

Modular: each part (fetching, sending, reporting) works independently.

## Project Goal
The goal of this project was to build a daily motivational quote email system that automates the full pipeline. From fetching quotes to sending them to users, without manual intervention.

##  System Architecture & Design Principles
# Separation of Concerns
The project is divided into three main scripts:

Quote Fetcher: fetches and stores the daily quote.

Email Sender: sends the quote to all active subscribers.

Admin Summary: emails a daily delivery report to the admin.

Each module has a single, clear responsibility, and they communicate via a shared SQLite database.
This makes it easy to replace or upgrade any one part without affecting others.

# Idempotence
The quote fetcher ensures that only one quote per day is stored in the database.
If you run it multiple times in one day, it won’t duplicate entries.
This keeps the system predictable and clean.

# Observability
Two layers of logging

This approach gives both quick visibility (via log files) and historical insights (via database records).

# System Components
 1. Quote Fetcher

Purpose: Fetch a motivational quote from the ZenQuotes API and store it in the database.
What it does:
Checks if a quote for today already exists.
If not, it fetches a new one from the API.
Validates the response before saving.
Logs success or failure.

Why this design:
It guarantees a single quote per day and keeps the quote-fetching logic completely independent of email operations.

2. Database (SQLite)

Purpose: Store all persistent informatioon
quotes: one record per day (quote, author, date).
users: subscriber info (name, email, status, frequency).
email_logs: records of every email sent, with delivery status and timestamp.

3. Email Sender

Purpose: Send today’s quote to all active subscribers and log delivery results.
What it does:
Reads SMTP credentials from the .env file.
Connects to the mail server (using SSL on port 465 for network reliability).
Personalizes each email (adds user’s name).
Sends the quote and logs each delivery result (success or failure).
Retries automatically for temporary network errors.

Why this design:
It ensures every user’s email result is recorded and that one user’s failure doesn’t block others.

4. Admin Summary Module

Purpose: Send a summary report to the admin after all user emails are sent.
What it includes:
Total number of users emailed.
Number of successful and failed sends.
The quote of the day.
Any error highlights.

Why separate:
It keeps reporting and delivery independent. If the summary email fails, it doesn’t affect the user mail delivery.

5. Logging and Monitoring

File logs: stored in /logs/ folder (for developers).
Database logs: email_logs table stores durable, per-user delivery info.
Together, they make it easy to debug issues and generate reports.


# Step-by-Step Summary

Set up project structure — Organized scripts and directories.

Created SQLite database — Added quotes, users, and email_logs tables.

Built the quote fetcher — Fetches, validates, and saves daily quotes.

Developed the email sender — Sends personalized emails and logs results.

Added the admin summary — Sends a daily performance report to the admin.

Implemented logging — Unified log format and per-user email tracking.

Improved error handling — Removed abrupt exits and added retries.

Configured environment management — Used python-dotenv and .env file for secrets.

Tested locally — Verified quote fetching, email sending, and logging.

Automated via Crontab— Scheduled daily cloud runs at 7:00 AM UTC.

## Docker Image 

The project has been containerized with Docker.

**Image URL:** `docker.io/katechisombili/mindfuel:latest`

Build the image:
docker build -t mindfuel:latest .


## How to Run

1. **Clone the repository**
```bash
git clone <YOUR_REPO_URL>
cd Dailyquotes
