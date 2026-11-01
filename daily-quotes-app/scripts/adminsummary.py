"""This is a script: A Daily summary email system that sends the admin a quick status report everyday
automatically after all user emails are sent"""

import os
import smtplib
import sqlite3
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import sys
from datetime import datetime, timezone



#create a log file
os.makedirs("logs", exist_ok=True)

#Set up logging, create a file called adminsummary.log, to track what happens every time the script runs
# Log to a file AND to the console. ECS collects console output for CloudWatch.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    handlers=[logging.FileHandler('logs/adminsummary.log'), logging.StreamHandler()]
)
logging.info("Starting the script... 3.2.1...")



SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", 465))
SENDER_EMAIL = os.getenv("EMAIL_ADDRESS")
SENDER_PASSWORD = os.getenv("EMAIL_PASSWORD")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL_ADDRESS")

if not all([SMTP_SERVER, SMTP_PORT, SENDER_EMAIL, SENDER_PASSWORD, ADMIN_EMAIL]):
    logging.error("Missing email configuration (check the environment variables)")
    sys.exit(1)
logging.info("Email configuration loaded successfully")

#Connect to the SQLite database
DB_PATH = os.environ.get("DB_PATH", "scripts/storage.db")
try:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    logging.info("Connected to the database successfully")
except Exception as e:
    logging.error(f"Cannot connect to the database: {e}")
    sys.exit(1)

#Fetch the status from the email logs table
today = datetime.now(timezone.utc).date().isoformat()
try:
    cur.execute("""
        SELECT
            COUNT(*),
            COALESCE(SUM(status = 'success'), 0),
            COALESCE(SUM(status = 'failed'), 0),
            COALESCE(SUM(status = 'pending'), 0)
        FROM email_logs
        WHERE sent_date = ?
    """, (today,))
    total_sent, success_count, fail_count, pending_count = cur.fetchone()
except Exception as e:
    logging.error(f"Failed to get email status from database: {e}")
    total_sent = success_count = fail_count = pending_count = 0


#Fetch today's quote
try:
    cur.execute(
	"SELECT quote, author FROM quotes WHERE date_fetched = ?", (today,))
    q = cur.fetchone()
    quote_text = q[0] if q else "No quote found"
    author= q[1] if q else "Unknown"
except Exception as e:
    logging.error(f"Failed to fetch quote: {e}")
    quote_text, author =  "No quote", "Unknown"

#Content of the email
try:
    subject = f"Daily Quote Delivery Summary"
    body = (
	f"Hello Admin, \n\n"
	f"Delivery summary for {today}:\n"
	f"Total attempts: {total_sent}\n"
	f"Delivered: {success_count}\n"
	f"Failed: {fail_count}\n"
    f"Stuck (claimed, not confirmed): {pending_count}\n"
	f"Quote of the Day:\n\"{quote_text}\"\n- {author}\n\n"
	f"Thank you"
)

    msg = MIMEMultipart()
    msg["From"] = SENDER_EMAIL
    msg["To"] = ADMIN_EMAIL
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain"))


    logging.info("Email message done")
except Exception as e:
    logging.error("Error while composing admin email")

#Sending the email through SSL(465 Port)
try:
    with smtplib.SMTP_SSL(SMTP_SERVER,SMTP_PORT, timeout=30) as server:
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.send_message(msg)
        logging.info("Mail successfully sent!")
except Exception as e:
    logging.error(f"Failed to send admin summary: {e}")
    sys.exit(1)
finally:
    if conn:
        conn.close()
        logging.info("Database CONNECTION CLOSED")

logging.info("WELDONE!")
