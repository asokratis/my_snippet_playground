# The query in http://stackoverflow.com/a/27863648/4461267 takes too much time to write manually when a lot of columns need to be exported.
# This script automates the process by supplying the columns and schema/table that need to be exported. 
# Example: sh query_unload_with_header.sh "column_1 column_2" "source_tables_for_export_to_s3" 
columnlist="$1"
tablelist="$2"
columncomma=""
headercomma=""
resultset=""
for i in $columnlist
do
resultset="$resultset, $i"
headercomma="$headercomma, '$i' AS $i"
columncomma="$columncomma, CAST($i AS varchar(8000))"
done
echo "SELECT${resultset#?} FROM ( SELECT 1 as i$headercomma UNION ALL SELECT 2 AS i$columncomma FROM $tablelist ) t ORDER BY i"
