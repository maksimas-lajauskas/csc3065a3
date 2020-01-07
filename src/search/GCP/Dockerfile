FROM debian
COPY ./gcp_keys.json /keys.json
COPY ./search.py /search.py
RUN apt-get update \
    && apt-get install -y python3 python3-pip nano less procps manpages man wget \
    && pip3 install requests bs4 google-cloud-bigtable lxml Flask waitress flask_cors pillow \
    && mkdir /templates \
    && mkdir /static
COPY ./templates /templates
#CMD ["python3", "/search.py"]
CMD ["ping", "google.com"]
