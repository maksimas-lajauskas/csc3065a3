FROM debian
RUN apt-get update \
    && apt-get install -y python3 python3-pip nano less procps manpages man \
    && pip3 install requests bs4 lxml flask waitress azure boto3
COPY . .
#CMD ["python3", "/crawler.py"]
CMD ["ping", "google.com"]
