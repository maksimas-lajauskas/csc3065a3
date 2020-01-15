import boto3
import os
from uuid import uuid1 as uuid
import json
import sys

#init environment
keyfile = "/root/.aws/credentials"
credvar1 = "aws_access_key_id"
credvar1 = os.environ[credvar1]
credvar2 = "aws_secret_access_key"
credvar2 = os.environ[credvar2]
credstring = f"[default]\naws_access_key_id = {credvar1}\naws_secret_access_key = {credvar2}"
os.mkdir(keyfile[:10])
f = open(keyfile,"w+")
f.write(credstring)
f.close()

bucketname = os.environ["QSE_STORAGE_BUCKET_NAME"]
storage_client = boto3.resource("s3")
bucket = storage_client.Bucket(bucketname)

def blob_to_string(blob):
	try:
		bytestring = blob.get()["Body"].read()
		checkstring = "{\"header\": \"".encode()
		if bytestring[:len(checkstring)] == checkstring:
			return bytestring.decode()
		else:
			return None
	except:
		print(sys.exc_info())
		return None

def locate_blob_prefix(prefix):
	for blob in bucket.objects.all():
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
	for blob in bucket.objects.all():
		try:
			b = blob_to_string(blob)
			if b is not None:
				j = json.loads(b)
				if j["header"] == header:
					blob.delete()
		except:
			continue

def locate_blob_exact(header):
	for blob in bucket.objects.all():
		try:
			b = blob_to_string(blob)
			if b is not None:
				j = json.loads(b)
				if j["header"] == header:
					return blob
		except:
			continue
	return None

#gcp variant should use "img_bytes" for referencing actual image's bytes' bucket name, aws object ==> object key, azure ==> ???
def ads_query(query_string):
	results = {}
	query_string_tokenised = query_string.split(" ")
	for blob in bucket.objects.all():
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
						"img_bytes": bucket.Object(j["data"]["img_bytes"]).get()["Body"].read()} # <-- test fetching blob directly from bucket outside of foreach
		except:
			print(sys.exc_info())
			continue
	return results

def search_query(query_string):
	results = {}
	query_string_tokenised = query_string.split(" ")
	for blob in bucket.objects.all():
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
		blob = bucket.Object(uuid().hex)
	bucket.put_object(Key = blob.key, Body = data)
	return blob.key
#datamodel: advert = {"header": "advert-<...>", "data": {"url": "<...>", "keywords": "<...>", "img_bytes": "<header of image bytes blob>", "img_height": "<...>", "img_width": "<...>", "img_mode": "<...>"}, "timestamp": "<...>" }
#datamodel: webpage = {"header": "webpage-<url>", "data": {"url": "<...>", "pagetext": "<...>"}, "timestamp": "<...>" }
#datamodel: ticket = {"header": "ticket-<url>", "data": "<url>", "timestamp": "<...>" }
#datamodel: image = {"header": "image-<...>", "data": "<bytes>"}

