"""Daily Quote Fetcher Script: It fetches one inspirational quote per day and stores it in a database"""

import requests
import sqlite3
import datetime
import logging
import os
import sys

"""Set up logging to both file and console"""
os.makedirs("logs", exist_ok=True)
logging.basicConfig(
    filename="logs/quotefetcher.log",
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    filemode="a"
)

console_handler=logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter=logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")
console_handler.setFormatter(formatter)
logging.getLogger().addHandler(console_handler)

logger = logging.getLogger(__name__)
logger.info("Starting the run, On your marks...")

"""Connect to SQLite Database, a file database called storage.db has already been set up"""

DB_PATH = os.environ.get("DB_PATH", "scripts/storage.db")
connection = sqlite3.connect(DB_PATH)
cur = connection.cursor()
logger.info("Successfully connected to Sqlite database")

"""Fetch a single quote from the API"""
def get_quote():
    try:
        logger.info("Fetching Quote from API")
        answer = requests.get("https://zenquotes.io/api/random", timeout=10)
        """Verify status code from HTTP"""
        if answer.status_code != 200:
            logger.warning(f"Non 200 status code: {answer.status_code}")
            return None, None

        data = answer.json()


        """Ensure the response we get is in good structure"""
        if not isinstance(data,list) or len(data) == 0:
            logger.warning("Malformed response: Not a list or empty.")
            return None, None

        quote_data = data[0]
        quote = quote_data.get("q")
        author = quote_data.get("a", "Unknown")

        if quote:
            return quote, author
        else:
            logger.warning("Received nothing from API")
        return None,None
    except Exception as e:
        logger.error(f"Error fetching Quote from API: {e}")
        return None, None


"""Check if we already have a quote for today"""

today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
cur.execute("SELECT COUNT(*) FROM quotes WHERE date_fetched = ?", (today,))
quote_exists= cur.fetchone()[0]

fetch_failed = False
if quote_exists:
    logger.info("Quote already exists for Today, skipping fetch")
    print("Quote exists in database")
else:
    quote, author = get_quote()
    if quote and author:
        cur.execute("INSERT INTO quotes (quote, author, date_fetched) VALUES (?, ?, ?)",
                    (quote, author, today))
        connection.commit()
        logger.info("Stored today's quotes Successfully")
    else:
        logger.error("Failed to insert new quote in the database")
        fetch_failed = True
connection.close()
logger.info("Database connection closed")

logger.info("Quote fetcher process complete")
if fetch_failed:
    sys.exit(1)














