#Superbasic crawler implementation - Maksimas Lajauskas 40073762
import socket
from random import getrandbits
from ipaddress import IPv4Address
import requests
import sys
import os
from bs4 import BeautifulSoup
import datetime
from google.cloud import bigtable

#storage interface
initialised = False
provider = os.environ["QSEPROVIDER"] # todo -> same as below

#common vars
common_credentials = None
common_page_content_column_name = os.environ["COMMON_PAGE_CONTENT_COLUMN_NAME"].encode()

#gcp vars
gcp_bigtable_instance = None
gcp_bigtable_index_table = None
gcp_bigtable_client = None
gcp_bigtable_colfam = None
gcp_project_id = None

def initialise():
    if provider == "GCP":
        gcp_project_id = os.environ["PROJECT_ID"]
        credentials = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
        gcp_bigtable_client = bigtable.Client.from_service_account_json(json_credentials_path=common_credentials,admin=True)

        gcp_bigtable_instance = client.instance(os.environ["GCP_BIGTABLE_INSTANCE"])
        gcp_bigtable_index_table = instance.table(os.environ["GCP_BIGTABLE_INDEX_TABLE"])
        gcp_bigtable_colfam = os.environ["GCP_BIGTABLE_COLUMN_FAMILY"].encode()

def write(url, text):
    if initialised is False:
        initialise()
    if provider == "GCP":
        write_gcp(url, text)

def write_gcp(url, text):
    row_key = url
    row = table.row(row_key)
    row.set_cell(gcp_bigtable_colfam,common_page_content_column_name,text,timestamp=datetime.datetime.utcnow())
    table.mutate_rows([row])

#main loop
while True:
    try:
        #random ip
        bits = getrandbits(32)
        addr = IPv4Address(bits)
        addr_str = str(addr)

        #send request
        req = requests.get(f"http://{addr_str}", timeout=2)
        bs = BeautifulSoup(req.text,"lxml")
        domain_name = socket.gethostbyaddr(addr_str)[0] #reverse dns lookup oneliner
        write(domain_name,bs.text)
    except:
        #should anything at all go wrong - scrap attempt and continue from start ad infinitum
        print(sys.exc_info())
        continue
