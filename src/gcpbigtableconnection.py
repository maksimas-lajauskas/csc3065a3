import datetime
from google.cloud import bigtable
from google.cloud.bigtable import column_family
from google.cloud.bigtable import row_filters

project_id = "cca3-263512"

instance_id = "qse-bigtable"

client = bigtable.Client.from_service_account_json(json_credentials_path="/keys.json",admin=True)

instance = client.instance(instance_id)

table = instance.table("qse-index")
row_key = "my-url" #
row = table.row(row_key)
row.set_cell("index","pagetext".encode(),"sometextvalue",timestamp=datetime.datetime.utcnow())
table.mutate_rows([row])
row_filter = row_filters.CellsColumnLimitFilter(1)
read_row = table.read_row(row_key.encode(), row_filter)
cell = read_row.cells["index"]["pagetext".encode()][0]
pagetext = cell.value.decode()

test_query_string = "mary had a little lamb text"
test_query_string_tokenised = test_query_string.split(" ")

matchscore = []
for word in test_query_string_tokenised:
    matchscore.append(0)

for i in range(1,len(test_query_string_tokenised)):
    if pagetext.find(test_query_string_tokenised[i]) >= 0:
            matchscore[i] = 1

if sum(matchscore) != len(matchscore):
	#skip to next
#search using filters...

#################################################################################
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
common_page_content_column_name = os.environ["COMMON_PAGE_CONTENT_COLUMN_NAME"].encode()

# gcp vars
gcp_bigtable_instance = None
gcp_bigtable_index_table = None
gcp_bigtable_client = None
gcp_bigtable_colfam = None
gcp_project_id = None


def initialise():
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
gcp_bigtable_colfam = os.environ["GCP_BIGTABLE_COLUMN_FAMILY"].encode()
initialised = True


def write(url, text):
    #if initialised is False:
        #initialise()
    if provider == "GCP":
        write_gcp(url, text)


def write_gcp(url, text):
    row_key = url
    row = gcp_bigtable_index_table.row(row_key)
    row.set_cell(
        gcp_bigtable_colfam,
        common_page_content_column_name,
        text,
        timestamp=datetime.datetime.utcnow(),
    )
    gcp_bigtable_index_table.mutate_rows([row])


# main loop
while True:
    try:
        # random ip
        bits = getrandbits(32)
        addr = IPv4Address(bits)
        addr_str = str(addr)
        # send request
        req = requests.get(f"http://{addr_str}", timeout=5)
        ips_good.append(addr_str)
        bs = BeautifulSoup(req.text, "lxml")
        domain_name = socket.gethostbyaddr(addr_str)[0]  # reverse dns lookup oneliner
        write(domain_name, bs.text)
    except:
        # should anything at all go wrong - scrap attempt and continue from start ad infinitum
        f = open("crawler.err.log", "a+")
        f.write(str(sys.exc_info()))
        f.close()
        continue


