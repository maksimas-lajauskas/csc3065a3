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
from google.cloud import bigtable
import binascii


app = Flask(__name__, static_url_path="/static")
cors = CORS(app)


# common vars
provider = os.environ["QSEPROVIDER"]#storage interface
remove_candidates = []
common_credentials = None
common_max_ads_per_page = int(os.environ["COMMON_MAX_ADS_PER_PAGE"])
common_image_file_persist_seconds = int(os.environ["COMMON_IMAGE_FILE_PERSIST_SECONDS"])
common_ads_image_column_name = os.environ["COMMON_ADS_IMAGE_COLUMN_NAME"]#Image.tobytes()
common_ads_image_height_column_name = os.environ["COMMON_ADS_IMAGE_HEIGHT_COLUMN_NAME"]#Image.size[1]
common_ads_image_width_column_name = os.environ["COMMON_ADS_IMAGE_WIDTH_COLUMN_NAME"]#Image.size[0]
common_ads_image_mode_column_name = os.environ["COMMON_ADS_IMAGE_MODE_COLUMN_NAME"]#Image.mode
common_ads_keywords_list_column_name = os.environ["COMMON_ADS_KEYWORDS_LIST_COLUMN_NAME"]

# gcp vars
gcp_bigtable_instance = None
gcp_bigtable_ads_table = None
gcp_bigtable_client = None
gcp_bigtable_ads_colfam = None
gcp_project_id = None

if provider == "GCP":
    gcp_project_id = os.environ["GCP_PROJECT_ID"]
    common_credentials = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
    gcp_bigtable_client = bigtable.Client.from_service_account_json(
        json_credentials_path=common_credentials, admin=True
    )
    gcp_bigtable_instance = gcp_bigtable_client.instance(os.environ["GCP_BIGTABLE_INSTANCE"])
    gcp_bigtable_ads_table = gcp_bigtable_instance.table(
        os.environ["GCP_BIGTABLE_ADS_TABLE"]
    )
    gcp_bigtable_ads_colfam = os.environ["GCP_BIGTABLE_ADS_COLUMN_FAMILY"]


def record_error():
    errstring = str(datetime.datetime.utcnow())+":\t"+str(sys.exc_info())+"\n"
    f = open("ads.err.log", "a+")
    f.write(errstring)
    f.close()
    print("ERROR:\t"+errstring)


def get_image_from_url(url):
    try:
        filename = uuid().hex
        subprocess.call(["wget","-O",filename,url])
        img = Image.open(filename)
        subprocess.call(["rm",filename])
        return img
    except:
        record_error()


def write(url, text, img):
    if provider == "GCP":
        return write_gcp(url, text, img)
    else:
        return False


def write_gcp(url, text, img):
    try:
        #bytes([x]) encodes int to bytes
        row_key = url
        row = gcp_bigtable_ads_table.row(row_key)
        timestamp = datetime.datetime.utcnow()
        row.set_cell(#keywords
            gcp_bigtable_ads_colfam.encode(),
            common_ads_keywords_list_column_name.encode(),
            text.encode(),
            timestamp=timestamp
        )
        row.set_cell(#width
            gcp_bigtable_ads_colfam.encode(),
            common_ads_image_width_column_name.encode(),
            bytes([img.size[0]]),
            timestamp=timestamp
        )
        row.set_cell(#height
            gcp_bigtable_ads_colfam.encode(),
            common_ads_image_height_column_name.encode(),
            bytes([img.size[1]]),
            timestamp=timestamp,
        )
        row.set_cell(#mode
            gcp_bigtable_ads_colfam.encode(),
            common_ads_image_mode_column_name.encode(),
            img.mode.encode(),
            timestamp=timestamp,
        )
        row.set_cell(#imgbytes
            gcp_bigtable_ads_colfam.encode(),
            common_ads_image_column_name.encode(),
            img.tobytes(),
            timestamp=timestamp,
        )
        gcp_bigtable_ads_table.mutate_rows([row])
        return True
    except:
        record_error()
        return False


def query(query_string):
    if provider == "GCP":
        return query_gcp(query_string)


def query_gcp(query_string):
    results = {}
    try:
        query_string_tokenised = query_string.split(",")
        for row in gcp_bigtable_ads_table.read_rows():
            pagetext = row.cells[gcp_bigtable_ads_colfam][common_ads_keywords_list_column_name.encode()][0].value.decode()
            matchscore = [] #accumulator
            for each_word in query_string_tokenised:
                matchscore.append(0)
            for i in range(0,len(query_string_tokenised)):
                if pagetext.casefold().find(query_string_tokenised[i].casefold()) >= 0:
                    matchscore[i] = 1
            if sum(matchscore) == len(matchscore):
                advert_data = {}
                advert_data["matches"] = sum(matchscore)
                advert_data["img_width"] = int(binascii.b2a_hex(row.cells[gcp_bigtable_ads_colfam][common_ads_image_width_column_name.encode()][0].value).decode(), 16)
                advert_data["img_height"] = int(binascii.b2a_hex(row.cells[gcp_bigtable_ads_colfam][common_ads_image_height_column_name.encode()][0].value).decode(), 16)
                advert_data["img_mode"] = row.cells[gcp_bigtable_ads_colfam][common_ads_image_mode_column_name.encode()][0].value.decode()
                advert_data["img_bytes"] = row.cells[gcp_bigtable_ads_colfam][common_ads_image_column_name.encode()][0].value
                results.update({row.row_key.decode() : advert_data})
        return results
    except:
        record_error()
        return results


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
        record_error()
        return False


def build_ads_payload(results):
    ads_payload = {}
    try:
        for result in results.keys():
            filename = uuid().hex+".gif"
            if build_img(filename, results.get(result)) is True:
                ads_payload[result] = filename
    except:
        record_error()
    return ads_payload


#THE SEP-arator (because / separates files and also stands for Search Engine Page and also method separates blank page from query page calls, endless fun!)
@app.route("/", methods=["GET"])
def page_separator():
  rqa = request.args  
  try:
      if request_from_inside(rqa):
        send_on(rqa)
      elif data_is_new(rqa):
        store_data(rqa)
      cleanup()
      return 200
  except:
      cleanup()
      record_error()
      return 500


def cleanup():
    try:
        for item in remove_candidates:
            if item[0]+common_image_file_persist_seconds < datetime.datetime.utcnow().timestamp():
                os.remove("/static/"+item[1])
                remove_candidates.remove(item)
    except:
        record_error()

    
#run server
def run():
  serve(app, host='0.0.0.0', port=80)


# run hook
if __name__ == "__main__":
  run()
