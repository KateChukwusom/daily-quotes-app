"""Import Built-in python library to connect to an email server and send mail,
fetch user and quote into from our local database, record what happens, format email properly and
 deliver successfully
"""
import os
import smtplib
import sqlite3
import logging
from email.utils import formataddr 
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timezone

import sys

# Load environment variables


SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", 465))
SENDER_EMAIL = os.getenv("EMAIL_ADDRESS")
SENDER_PASSWORD = os.getenv("EMAIL_PASSWORD")

# Make sure the logs folder exists. A fresh container won't have one,
# and logging to a missing folder crashes the script.
os.makedirs("logs", exist_ok=True)


# Setup logging
# Log to a file AND to the console. ECS collects console output,
# so this is what is seen in CloudWatch.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    handlers=[logging.FileHandler('logs/emailsender.log'), logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

# Verify email configuration
if not all([SMTP_SERVER, SMTP_PORT, SENDER_EMAIL, SENDER_PASSWORD]):
    logger.error("Missing email configuration in .env file")
else:
    logger.info("Email configuration loaded successfully")

# Database connection
DB_PATH = os.environ.get("DB_PATH", "scripts/storage.db")


try:
    connection = sqlite3.connect(DB_PATH)
    cur = connection.cursor()
    logger.info("Connected to SQLite database")
except Exception as e:
    logger.error(f"Database connection failed: {e}")
    connection = None

# Get today's quote
today = datetime.now(timezone.utc).date().isoformat()
quote, author = None, None

if connection:
    cur.execute("SELECT id, quote, author FROM quotes WHERE date_fetched = ?", (today,))
    row = cur.fetchone()
    if row:
        _, quote, author = row
        logger.info("Found today's quote")
    else:
        logger.warning("No quote found for today")

# Fetch active users who have NOT received today's email
users = []
if connection:
    cur.execute("""
        SELECT u.name, u.email
        FROM users u
        WHERE u.status = 'active'
          AND u.frequency = 'daily'
          AND NOT EXISTS (
              SELECT 1 FROM email_logs e
              WHERE e.email = u.email
                AND e.sent_date = ?
                AND e.status IN ('pending', 'success')
          )
    """, (today,))
    users = cur.fetchall()

    if users:
        logger.info(f"{len(users)} active users to email")
    else:
        logger.info("No users to email today (all already sent)")

failures = 0
# Send emails
if quote and author and users:
    try:
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
            logger.info("Logged into SMTP server successfully.")

            for name, email in users:

                try:
                    cur.execute(
                        "INSERT INTO email_logs (email, sent_date, status) VALUES (?, ?, 'pending')",
                        (email, today))
                    connection.commit()
                    log_id = cur.lastrowid
                except sqlite3.IntegrityError:
                    logger.info(f"Skipping {email}: already handled today")
                    continue


                body = f"Dear {name},\n\n\"{quote}\"\n-- {author}\n\nGo conquer the world!"
                msg = MIMEMultipart()
                msg["From"] = formataddr(("MindFuel", SENDER_EMAIL))
                msg["To"] = email
                msg["Subject"] = "Your Daily Dose of Inspiration"
                msg.attach(MIMEText(body, "plain"))

                
                try:
                    server.send_message(msg)
                    new_status = "success"
                    logger.info(f"Email sent successfully to {email}")
                except Exception as e:
                    new_status = "failed"   # frees the claim so a retry can run
                    failures += 1
                    logger.error(f"Failed to send email to {email}: {e}")
                cur.execute("UPDATE email_logs SET status = ? WHERE id = ?", (new_status, log_id))
                connection.commit()


                    ##
                # subject = "Your Daily Dose of Inspiration"
                # body = f"Dear {name},\n\n\"{quote}\"\n-- {author}\n\nGo conquer the world!"

                # msg = MIMEMultipart()
                # msg["From"] = formataddr(("MindFuel", SENDER_EMAIL))
                # msg["To"] = email
                # msg["Subject"] = subject
                # msg.attach(MIMEText(body, "plain"))

                # try:
                #     server.send_message(msg)
                #     logger.info(f"Email sent successfully to {email}")

                #     # Record in email_logs
                #     cur.execute("""
                #         INSERT INTO email_logs (email, quote, author, status)
                #         VALUES (?, ?, ?, ?)
                #     """, (email, quote, author, 'success'))
                #     connection.commit()

                # except Exception as e:
                #     logger.error(f"Failed to send email to {email}: {e}")
                #     cur.execute("""
                #         INSERT INTO email_logs (email, quote, author, status)
                #         VALUES (?, ?, ?, ?)
                #     """, (email, quote, author, 'failed'))
                #     connection.commit()

    except Exception as e:
        logger.error(f"SMTP connection error: {e}")
        failures += 1
else:
    if not quote:
        logger.error("No quote for today; nothing sent")
        failures += 1
    else:
        logger.info("No users to email today")

if connection:
    connection.close()

logger.info("Email sending process complete")
sys.exit(1 if failures else 0)