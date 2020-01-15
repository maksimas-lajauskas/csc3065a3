from google.cloud import storage
import os
from uuid import uuid1 as uuid
from base64 import urlsafe_b64decode
import json
import sys

#init environment
keyfile = "keys.json"
credvar = "GOOGLE_APPLICATION_CREDENTIALS"
f = open(keyfile,"w+")
f.write(urlsafe_b64decode(os.environ[credvar][2:-1].encode()).decode())
f.close()
os.environ[credvar] = os.path.abspath(keyfile)

bucketname = os.environ["QSE_STORAGE_BUCKET_NAME"]
storage_client = storage.Client()
bucket = storage_client.bucket(bucketname)

def blob_to_string(blob):
	try:
		bytestring = blob.download_as_string()
		checkstring = "{\"header\": \"".encode()
		if bytestring[:len(checkstring)] == checkstring:
			return bytestring.decode()
		else:
			return None
	except:
		print(sys.exc_info())
		return None

def locate_blob_prefix(prefix):
	for blob in bucket.list_blobs():
		try:
			b = blob_to_string(blob)
			if b is not None:
				j = json.loads(b)
				if j["header"][:len(prefix)] == prefix:
					return blob
		except:
			continue
	return None

def delete_blob(header):
	for blob in bucket.list_blobs():
		try:
			b = blob_to_string(blob)
			if b is not None:
				j = json.loads(blob)
				if j["header"] == header:
					blob.delete()
		except:
			continue

def locate_blob_exact(header):
	for blob in bucket.list_blobs():
		try:
			b = blob_to_string(blob)
			if b is not None:
				j = json.loads(b)
				if j["header"] == header:
					return blob
		except:
			continue
	return None

def ads_query(query_string):
	results = {}
	query_string_tokenised = query_string.split(" ")
	for blob in bucket.list_blobs():
		try:
			b = blob_to_string(blob)
			if b is not None:
				j = json.loads(b)
				if j["header"][:7] == "advert-":
					matchscore = 0
					for i in query_string_tokenised:
						if j["data"]["keywords"].casefold().find(i.casefold()) >= 0:
							matchscore += 1
					if matchscore == 0:
						continue
					else:
						results[j["data"]["url"]] = {"img_height" : j["data"]["img_height"],
						"img_width": j["data"]["img_width"],
						"img_mode": j["data"]["img_mode"],
						"img_bytes": bucket.blob(j["data"]["img_bytes"]).download_as_string()}
		except:
			print(sys.exc_info())
			continue
	return results

def search_query(query_string):
	results = {}
	query_string_tokenised = query_string.split(" ")
	for blob in bucket.list_blobs():
		try:
			b = blob_to_string(blob)
			if b is not None:
				j = json.loads(b)
				if j["header"][:8] == "webpage-":
					matchscore = 0
					for i in query_string_tokenised:
						if j["data"]["pagetext"].casefold().find(i.casefold()) >= 0:
							matchscore += 1
					if matchscore != len(query_string_tokenised):
						continue
					else:
						results[j["data"]["url"]] = j["data"]["pagetext"][:100].replace("\n"," ").replace("<!--", "").replace("-->", "")+"..."
		except:
			continue
			print(sys.exc_info())
	return results

#e.g. testdata1 = {"header": "webpage-<url>", "data": {"url": "<...>", "pagetext": "<...>"}, "timestamp": datetime.datetime.utcnow().timestamp() }
# write(testdata1["header"],json.dumps(testdata1).encode())
def write(data, header=None): #assumes data (containing redundant header) == bytes
	blob = None
	if header is not None:
		blob = locate_blob_exact(header)
	if blob is None:
		blob = bucket.blob(uuid().hex)
	blob.upload_from_string(data)
	return blob.name
#datamodel: advert = {"header": "advert-<...>", "data": {"url": "<...>", "keywords": "<...>", "img_bytes": "<header of image bytes blob>", "img_height": "<...>", "img_width": "<...>", "img_mode": "<...>"}, "timestamp": "<...>" }
#datamodel: webpage = {"header": "webpage-<url>", "data": {"url": "<...>", "pagetext": "<...>"}, "timestamp": "<...>" }
#datamodel: ticket = {"header": "ticket-<url>", "data": "<url>", "timestamp": "<...>" }
#datamodel: image = {"header": "image-<...>", "data": "<bytes>"}

