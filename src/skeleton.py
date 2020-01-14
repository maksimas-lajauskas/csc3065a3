#skeleton to build rest of apps from...
import os

if os.environ["QSEPROVIDER"] == "GCP":
	import gcp_storage_interface
	from gcp_storage_interface import write()
	from gcp_storage_interface import locate_blob_prefix()
	from gcp_storage_interface import delete_blob()
	from gcp_storage_interface import locate_blob_exact()
	from gcp_storage_interface import ads_query()
	from gcp_storage_interface import search_query()
elif os.environ["QSEPROVIDER"] == "AWS":
	import aws_storage_interface
	from aws_storage_interface import write()		
	from aws_storage_interface import locate_blob_prefix()
	from aws_storage_interface import delete_blob()
	from aws_storage_interface import locate_blob_exact()
	from aws_storage_interface import ads_query()
	from aws_storage_interface import search_query()
elif os.environ["QSEPROVIDER"] == "AZURE":
	import azure_storage_interface
	from azure_storage_interface import write()
	from azure_storage_interface import locate_blob_prefix()
	from azure_storage_interface import delete_blob()
	from azure_storage_interface import locate_blob_exact()
	from azure_storage_interface import ads_query()
	from azure_storage_interface import search_query()



