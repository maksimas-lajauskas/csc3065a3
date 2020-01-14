FROM debian
RUN apt-get update \
    && apt-get install -y python3 python3-pip nano less procps manpages man wget \
    && pip3 install requests bs4 google-cloud-bigtable lxml Flask waitress flask_cors pillow
COPY . .
CMD ["python3", "/ads.py"]
