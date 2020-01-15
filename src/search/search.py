# Superbasic crawler implementation - Maksimas Lajauskas 40073762
from uuid import uuid1 as uuid
import traceback
from PIL import Image
from flask import Flask, request, render_template
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

app = Flask(__name__)
cors = CORS(app)

# common vars
provider = os.environ["QSEPROVIDER"]#storage interface
remove_candidates = []

if os.environ["QSEPROVIDER"] == "GCP":
    import gcp_storage_interface
    from gcp_storage_interface import write
    from gcp_storage_interface import locate_blob_prefix
    from gcp_storage_interface import delete_blob
    from gcp_storage_interface import locate_blob_exact
    from gcp_storage_interface import ads_query
    from gcp_storage_interface import search_query
elif os.environ["QSEPROVIDER"] == "AWS":
    import aws_storage_interface
    from aws_storage_interface import write
    from aws_storage_interface import locate_blob_prefix
    from aws_storage_interface import delete_blob
    from aws_storage_interface import locate_blob_exact
    from aws_storage_interface import ads_query
    from aws_storage_interface import search_query
elif os.environ["QSEPROVIDER"] == "AZURE":
    import azure_storage_interface
    from azure_storage_interface import write
    from azure_storage_interface import locate_blob_prefix
    from azure_storage_interface import delete_blob
    from azure_storage_interface import locate_blob_exact
    from azure_storage_interface import ads_query
    from azure_storage_interface import search_query


def build_img(filename, imgdata):
    try:
        img = Image.frombytes(
        mode = imgdata["img_mode"],
        size = (imgdata["img_width"], imgdata["img_height"]),
        data = imgdata["img_bytes"]
        )
        img.save(os.path.abspath("/static/"+filename))
        remove_candidates.append((datetime.datetime.utcnow().timestamp(), filename))
        return True
    except:
        record_error()
        return False


def build_ads_payload(results):
    ads_payload = {}
    for result in results.keys():
        try:
            filename = uuid().hex+".gif"
            if build_img(filename, results[result]) is True:
                ads_payload[result] = filename
        except:
            record_error()
            continue
    return ads_payload


def cleanup():
    for item in remove_candidates:
        try:
            if item[0]+common_image_file_persist_seconds < datetime.datetime.utcnow().timestamp():
                os.remove(os.path.abspath("/static/"+item[1]))
                remove_candidates.remove(item)
        except:
            record_error()
            continue


#THE SEP-arator (because / separates files and also stands for Search Engine Page and also method separates blank page from query page calls, endless fun!)
@app.route("/", methods=["GET"])
def serve_page():
  rqa = request.args  
  try:
      ads_payload = build_ads_payload(ads_query(rqa.get("q")))
      results_payload = search_query(rqa.get("q"))
      cleanup()
      return render_template("serp.html", ads_payload=ads_payload, results_payload=results_payload)
  except:
      cleanup()
      record_error()
      return render_template("index.html")

def record_error():
    f = open("LOGFILE","a+")
    e = sys.exc_info()
    f.write(str(e)+"\n"+str(traceback.extract_tb(e[2])))
    f.close()
     
#run server
def run():
  serve(app, host='0.0.0.0', port=80)


#run hook
if __name__ == "__main__":
  run()

