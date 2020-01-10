# Superbasic crawler implementation - Maksimas Lajauskas 40073762
import socket
from random import getrandbits
from ipaddress import IPv4Address
import requests
import sys
import os
from bs4 import BeautifulSoup
import datetime
from google.cloud import bigtable

# storage interface
initialised = False
provider = os.environ["QSEPROVIDER"]  # todo -> same as below

# common vars
common_credentials = None
common_page_content_column_name = os.environ["COMMON_PAGE_CONTENT_COLUMN_NAME"]

# gcp vars
if provider == "GCP":
    gcp_project_id = os.environ["GCP_PROJECT_ID"]
    common_credentials = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
    gcp_bigtable_client = bigtable.Client.from_service_account_json(
        json_credentials_path=common_credentials, admin=True
    )
    gcp_bigtable_instance = gcp_bigtable_client.instance(os.environ["GCP_BIGTABLE_INSTANCE"])
    gcp_bigtable_index_table = gcp_bigtable_instance.table(
        os.environ["GCP_BIGTABLE_INDEX_TABLE"]
    )
    gcp_bigtable_colfam = os.environ["GCP_BIGTABLE_COLUMN_FAMILY"]
    initialised = True


def write(url, text):
    #if initialised is False:
        #initialise()
    if provider == "GCP":
        return write_gcp(url, text)
    else:
        return False


def write_gcp(url, text):
    try:
        row_key = url
        row = gcp_bigtable_index_table.row(row_key)
        row.set_cell(
            gcp_bigtable_colfam.encode(),
            common_page_content_column_name.encode(),
            text.encode(),
            timestamp=datetime.datetime.utcnow(),
        )
        gcp_bigtable_index_table.mutate_rows([row])
        return True
    except:
        errstring = str(datetime.datetime.utcnow())+":\t"+str(sys.exc_info())+"\n"
        f = open("crawler.err.log", "a+")
        f.write(errstring)
        f.close()
        print("ERROR:\t"+errstring)
        return False


def crawl_random():
    try:
        # random ip
        bits = getrandbits(32)
        addr = IPv4Address(bits)
        addr_str = str(addr)
        print("Attempting: "+addr_str)
        # send request
        req = None
        prefix = "https://"
        try:
            req = requests.get(f"https://{addr_str}", timeout=10)
        except:
            prefix = "http://"
            req = requests.get(f"http://{addr_str}", timeout=10)
        bs = BeautifulSoup(req.text, "lxml")
        domain_name = None
        try:
            domain_name = socket.gethostbyaddr(addr_str)[0]  # reverse dns lookup oneliner
        except:
            domain_name = addr_str
        f = open("crawler.storage.log", "a+")
        f.write(str(datetime.datetime.utcnow())+":\t"+str({prefix+domain_name : bs.text})+"\n")
        f.close()
        if write(domain_name, bs.text):
            print("success"+domain_name)
        return True
    except:
        # should anything at all go wrong - scrap attempt and continue from start ad infinitum
        errstring = str(datetime.datetime.utcnow())+":\t"+str(sys.exc_info())+"\n"
        f = open("crawler.err.log", "a+")
        f.write(errstring)
        f.close()
        print("ERROR:\t"+errstring)
        return False


def get_status_update():
    current_state = {}
    for row in gcp_bigtable_index_table.read_rows():
        current_state.update({row.row_key.decode() : row.cells[gcp_bigtable_colfam][common_page_content_column_name.encode()][0].value.decode()})
    i = 1
    l = len(current_state)
    f = open("crawler.success.log", "w+")
    for item in current_state:
        f.write(str(i)+"/"+str(l)+":\t"+str(item)+"\n")
        i = i + 1
    f.close()

#main loop
while True:
    if crawl_random():
        get_status_update()

