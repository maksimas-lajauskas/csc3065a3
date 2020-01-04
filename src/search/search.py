# Superbasic crawler implementation - Maksimas Lajauskas 40073762
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

# storage interface
initialised = False
provider = os.environ["QSEPROVIDER"]  # todo -> same as below

# common vars
common_credentials = None
common_page_content_column_name = os.environ["COMMON_PAGE_CONTENT_COLUMN_NAME"]

# gcp vars
gcp_bigtable_instance = None
gcp_bigtable_index_table = None
gcp_bigtable_client = None
gcp_bigtable_colfam = None
gcp_project_id = None
gcp_ads_service_ip = None


if provider == "GCP":
    # gcp_ads_service_ip = os.environ["GCP_ADS_SERVICE_IP"]
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


def respond(contents):
  response = Response(contents)
  return response


def query(query_string):
    if provider == "GCP":
        return query_gcp(query_string)


def query_gcp(query_string):
    results = {}
    query_string_tokenised = query_string.split(" ")
    for row in gcp_bigtable_index_table.read_rows():
        pagetext = row.cells[gcp_bigtable_colfam][common_page_content_column_name.encode()][0].value.decode()
        #accumulator
        matchscore = []
        for each_word in query_string_tokenised:
            matchscore.append(0)
        for i in range(0,len(query_string_tokenised)):
            if pagetext.casefold().find(query_string_tokenised[i].casefold()) >= 0:
                matchscore[i] = 1
        if sum(matchscore) != len(matchscore):
            continue
        else:
            results.update({row.row_key.decode():pagetext[:100].replace("\n"," ").replace("<!--", "").replace("-->", "")+"..."})
    return results


def build_html_start():
    return """
<!DOCTYPE html>
<html>
    <body>
        <h1>QSE Search Engine</h1>
        <form action="/" method="get">
            <input type="text" name="q">
            <input type="submit" value="QSE Search">
        </form>
        <hr/>
    <body>
</html>
"""


def build_html_serp(results):
    serp = """
<!DOCTYPE html>
<html>
    <body>
        <h1>QSE Search Engine</h1>
        <form action="/" method="get">
            <input type="text" name="q">
            <input type="submit" value="QSE Search">
        </form>
        <hr/>
"""
    for result in results.keys():
        serp+=f"""
<div>
    <a href="http://{result}">{result}</a><br/>
    <p>{results.get(result)}</p>
</div>
"""
    serp+="""
    <body>
</html>
"""
    return serp


#THE SEP-arator (because / separates files and also stands for Search Engine Page and also separates blank page from query page calls, endless fun!)
@app.route("/", methods=["GET"])
def page_separator():
  rqa = request.args  
  try:
    return respond(build_html_serp(query(rqa.get("q"))))
  except:
    return respond(build_html_start())   

    
#run server
def run():
  serve(app, host='0.0.0.0', port=80)


#run hook
if __name__ == "__main__":
  run()

