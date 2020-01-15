# Superbasic crawler implementation - Maksimas Lajauskas 40073762
import socket
import traceback
from random import getrandbits
from ipaddress import IPv4Address
import requests
import sys
import os
from bs4 import BeautifulSoup
import datetime
import threading
from flask import Flask, request
from waitress import serve

#webstuff
app = Flask(__name__)

# storage interface
provider = os.environ["QSEPROVIDER"]  # todo -> same as below

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


def rand_ip():
    # random ip
    bits = getrandbits(32)
    addr = IPv4Address(bits)
    addr_str = str(addr)
    domain_name = addr_str
    try:
        domain_name = socket.gethostbyaddr(addr_str)[0]  # reverse dns lookup oneliner
        return domain_name
    except:
        record_error()
        return domain_name


def crawl_url(addr_str):
    # send request
    req = None
    prefix = ""
    timestamp = datetime.datetime.utcnow().timestamp()
    entry = {"header": f"webpage-{prefix+addr_str}", "data": {"url": prefix+addr_str, "pagetext": "qse-not-available"}, "timestamp": timestamp }
    if addr_str[:4] != "http":
        prefix = "https://"
    try:
        try:
            req = requests.get(f"https://{addr_str}", timeout=10)
        except:
            prefix = "http://"
            req = requests.get(f"http://{addr_str}", timeout=10)
        bs = BeautifulSoup(req.text, "lxml")
        entry["data"]["pagetext"] = bs.text
        write(header = entry["header"],data = json.dumps(entry).encode())
    except:
        record_error()
        write(header = entry["header"],data = json.dumps(entry).encode())


def main_loop():
    while True:
        try:
            q = locate_blob_prefix("ticket-")
            if q is not None:
                ticket = json.loads(blob_to_string(q))
                delete_blob(q)
                crawl_url(ticket["data"])
            else:
                crawl_url(rand_ip())
        except:
            record_error()
            continue


crawler_thread = threading.Thread(target = main_loop , daemon = True)

def record_error():
    f = open("LOGFILE","a+")
    e = sys.exc_info()
    f.write(str(e)+"\n"+str(traceback.extract_tb(e[2])))
    f.close()
 


def run():
    crawler_thread.start()
    serve(app,host="0.0.0.0",port=80)


if __name__ == "__main__":
    run()



