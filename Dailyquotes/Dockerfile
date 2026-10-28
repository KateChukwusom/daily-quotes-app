FROM python:3.12-slim

# Working directory inside container
WORKDIR /app

# Copy requirements file and install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY scripts/ ./scripts/
COPY exec.sh ./

# Copy cron schedule and entrypoint
COPY crontab ./crontab
COPY docker-entrypoint.sh ./docker-entrypoint.sh

# Make scripts executable
RUN chmod +x exec.sh docker-entrypoint.sh && mkdir -p /app/logs

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Install cron
RUN apt-get update && \
    apt-get install -y cron && \
    rm -rf /var/lib/apt/lists/*

# Start container with cron running
ENTRYPOINT ["./docker-entrypoint.sh"]
