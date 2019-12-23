#Superbasic crawler implementation - Maksimas Lajauskas 40073762
import requests
import socket
from random import getrandbits
from ipaddress import IPv4Address

if True:
    #step1 pick IP
    bits = getrandbits(32)
    addr = IPv4Address(bits)
    addr_str = str(addr)
    print(addr_str)

    #check if has record in DB

    #reverse dns lookup oneliner
#   socket.gethostbyaddr(addr_str)[0]
    #((record exists && time to revisit) || norecord )? continue : next IP
