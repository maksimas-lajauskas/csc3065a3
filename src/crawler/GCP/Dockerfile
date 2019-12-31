FROM debian
COPY ./gcp_keys.json /keys.json
RUN export GOOGLE_APPLICATION_CREDENTIALS="/keys.json"
RUN export QSEPROVIDER="GCP"
RUN apt-get update && apt-get install -y python3 python3-pip && pip3 install requests bs4 google-cloud-bigtable
CMD ["ping", "google.com"]
