#!/bin/bash

#change directory into quotesapp,if fails, then exit
cd /quotesapp || exit 1

#create a variable called status=0, 0 means success 
status=0

#rub the python script, if fails, set status=1
python3 scripts/setup_db.py || status=1
python3 scripts/quotefetcher.py || status=1
python3 scripts/emailsender.py || status=1
python3 scripts/adminsummary.py || status=1

echo "$(date -u) | Daily run completed (exit code $status)"
exit $status
