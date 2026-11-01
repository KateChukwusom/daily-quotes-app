FROM python:3.12-slim

#set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

#create folder for the running container
WORKDIR /quotesapp

#Copy the requirements.txt into the quotesapp
COPY requirements.txt .

#install the requirements and do not keep the download cache
RUN pip install --no-cache-dir -r requirements.txt

#Copy the scripts into the image scripts
COPY scripts/ ./scripts/



#Copy the .sh file 
COPY exec.sh .

#Make the exec.sh executable, create a user and a logs folder
#Change the ownership of the quotesapp to the user guy so the user can be used to create file and write logs
RUN chmod +x exec.sh \
 && useradd --create-home --uid 1000 quotesapp \
 && mkdir -p logs \
 && chown -R quotesapp:quotesapp /quotesapp

USER quotesapp

CMD ["./exec.sh"]