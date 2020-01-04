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

def query(query_string):
	results = {}
	query_string_tokenised = query_string.split(" ")
	for row in gcp_bigtable_index_table.read_rows():
		pagetext = row.cells[gcp_bigtable_colfam][common_page_content_column_name.encode()][0].value.decode()
		#accumulator
		matchscore = []
		for each_word in query_string_tokenised:
			matchscore.append(0)
		for i in range(0,len(query_string_tokenised)):
			print("searching "+row.row_key+" for "+query_string_tokenised[i].casefold())
			if pagetext.casefold().find(query_string_tokenised[i].casefold()) >= 0:
				matchscore[i] = 1
				print("match")
		if sum(matchscore) != len(matchscore):
			continue
		else:
			results.update({row.row_key:pagetext[100:]})
	return results

#################################################################################
#python repl gcp init / connect code to copy&paste
from flask import Flask, request, jsonify, Response
from waitress import serve
from flask_cors import CORS, cross_origin
import subprocess
import json
import socket
from random import getrandbits
from ipaddress import IPv4Address
import requests
import sys
import os
from bs4 import BeautifulSoup
import datetime
from google.cloud import bigtable
app = Flask(__name__)
cors = CORS(app)
provider = os.environ["QSEPROVIDER"]  # todo -> same as below
common_page_content_column_name = os.environ["COMMON_PAGE_CONTENT_COLUMN_NAME"]
gcp_ads_service_ip = os.environ["GCP_ADS_SERVICE_IP"]
gcp_project_id = os.environ["GCP_PROJECT_ID"]
common_credentials = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
gcp_bigtable_client = bigtable.Client.from_service_account_json(
    json_credentials_path=common_credentials, admin=False
)
gcp_bigtable_instance = gcp_bigtable_client.instance(os.environ["GCP_BIGTABLE_INSTANCE"])
gcp_bigtable_index_table = gcp_bigtable_instance.table(
    os.environ["GCP_BIGTABLE_INDEX_TABLE"]
)
gcp_bigtable_colfam = os.environ["GCP_BIGTABLE_COLUMN_FAMILY"]
initialised = True

