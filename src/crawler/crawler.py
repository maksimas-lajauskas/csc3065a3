#Superbasic crawler implementation - Maksimas Lajauskas 40073762
import requests
import socket
from random import getrandbits
from ipaddress import IPv4Address
import requests
import sys
from bs4 import BeautifulSoup

while True:
    try:
        #random ip
        bits = getrandbits(32)
        addr = IPv4Address(bits)
        addr_str = str(addr)

        #reverse dns lookup oneliner
#        domain_name = socket.gethostbyaddr(addr_str)[0]

        #send request
        req = requests.get(f"http://{addr_str}")
        bs = BeautifulSoup(req.text,"lxml")
        print(bs.text)
    except:
        #should anything at all go wrong - scrap attempt and continue from start ad infinitum
        print(sys.exc_info())
        continue

