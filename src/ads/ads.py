import subprocess
from uuid import uuid1 as uuid
from PIL import Image
from flask import Flask, render_template, request
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


app = Flask(__name__, static_url_path="/static")


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

def get_image_from_url(url):
    filename = uuid().hex
    subprocess.call(["wget","-O",filename,url])
    img = Image.open(filename)
    subprocess.call(["rm",filename])
    return img


def handle_write(url, text, img):
    try:
        header = "advert-"+url
        imgname = write(img.tobytes())
        timestamp = datetime.datetime.utcnow().timestamp()
        data = {"header": header,
        "data": {"url": url,
        "keywords": text,
        "img_bytes": imgname,
        "img_height": img.size[1],
        "img_width": img.size[0],
        "img_mode": img.mode},
        "timestamp": timestamp }
        print(data)
        data = json.dumps(data).encode()
        print(data)
        write(data = data, header = header)
        return True
    except:
        return False


def build_img(filename, imgdata):
    try:
        img = Image.frombytes(
        mode = imgdata.get("img_mode"),
        size = (imgdata.get("img_width"), imgdata.get("img_height")),
        data = imgdata.get("img_bytes")
        )
        img.save("/static/"+filename)
        remove_candidates.append((datetime.datetime.utcnow().timestamp(), filename))
        return True
    except:
        print(sys.exc_info())
        return False


def build_ads_payload(results):
    ads_payload = {}
    for result in results:
        filename = uuid().hex+".gif"
        if build_img(filename, result) is True:
            ads_payload[result["data"]["url"]] = filename
    return ads_payload


#THE SEP-arator (because / separates files and also stands for Search Engine Page and also method separates blank page from query page calls, endless fun!)
@app.route("/", methods=["GET"])
def page_separator():
  rqa = request.args  
  try:
      img = get_image_from_url(rqa.get("imgurl"))
      handle_write(rqa.get("url"),rqa.get("keywords"),img)
      ads_payload = build_ads_payload(ads_query(rqa.get("keywords")))
      cleanup()
      return render_template("serp.html", ads_payload=ads_payload)
  except:
      cleanup()
      return render_template("index.html")


def cleanup():
    for item in remove_candidates:
        if item[0]+common_image_file_persist_seconds < datetime.datetime.utcnow().timestamp():
            os.remove("/static/"+item[1])
            remove_candidates.remove(item)

    
#run server
def run():
  serve(app, host='0.0.0.0', port=80)


# run hook
if __name__ == "__main__":
  run()
