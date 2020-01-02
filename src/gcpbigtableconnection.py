import datetime
from google.cloud import bigtable
from google.cloud.bigtable import column_family
from google.cloud.bigtable import row_filters

project_id = "cca3-263512"

instance_id = "qse-bigtable"

client = bigtable.Client.from_service_account_json(json_credentials_path="/keys.json",admin=True)

instance = client.instance(instance_id)

table = instance.table("qse-index")
row_key = "my-url" #
row = table.row(row_key)
row.set_cell("index","pagetext".encode(),"sometextvalue",timestamp=datetime.datetime.utcnow())
table.mutate_rows([row])
row_filter = row_filters.CellsColumnLimitFilter(1)
read_row = table.read_row(row_key.encode(), row_filter)
cell = read_row.cells["index"]["pagetext".encode()][0]
pagetext = cell.value.decode()

test_query_string = "mary had a little lamb text"
test_query_string_tokenised = test_query_string.split(" ")

matchscore = []
for word in test_query_string_tokenised:
    matchscore.append(0)

for i in range(1,len(test_query_string_tokenised)):
    if pagetext.find(test_query_string_tokenised[i]) >= 0:
            matchscore[i] = 1

if sum(matchscore) != len(matchscore):
	#skip to next
#search using filters...
