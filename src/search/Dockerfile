FROM debian
RUN apt-get update \
    && apt-get install -y python3 python3-pip nano less procps manpages man wget \
    && pip3 install requests bs4 lxml Flask waitress flask_cors pillow google-cloud-storage azure-identity azure-storage-blob boto3 \
    && mkdir /static
COPY . .
CMD ["python3", "/search.py"]
#CMD ["ping", "google.com"]
