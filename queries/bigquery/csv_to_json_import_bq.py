# Uses Messytables example (https://messytables.readthedocs.io/en/latest/#example)
# To extract from a CSV flatfile the required BIGQUERY JSON metadata
# For importing a table in BIGQUERY
# Example: python csv_to_json_import_bq.py the_csv_file.csv
from messytables import CSVTableSet, type_guess, \
types_processor, headers_guess, headers_processor, \
offset_processor, any_tableset
import sys

fh = open(sys.argv[1], 'rb')
table_set = CSVTableSet(fh)
row_set = table_set.tables[0]
offset, headers = headers_guess(row_set.sample)
row_set.register_processor(headers_processor(headers))
row_set.register_processor(offset_processor(offset+1))
types = type_guess(row_set.sample, strict=True)

for i in range(len(headers)):
    output = ""
    if ("DATE" in str(types[i]).upper()):
        types[i] = "TIMESTAMP"
    elif ("DECIMAL" in str(types[i]).upper()):
        types[i] = "FLOAT"
    output = "{\"name\":\"" + str(headers[i]).lower() + "\", \"type\":\"" + str(types[i]).upper() + "\"}"
    if i == (len(headers)-1):
        output += "\n]"
    else:
        output += ","
    print output
