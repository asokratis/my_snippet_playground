# The query in http://stackoverflow.com/a/27863648/4461267 takes too much time to write manually when a lot of columns need to be exported.
# This script automates the process by supplying the columns and schema/table that need to be exported.
# Example: sh query_unload_with_header.sh "column_1 column_2" "source_tables_for_export_to_s3"
# Version 1.01: Handles scalar values. Example: sh query_unload_with_header.sh "column_1 upper(column_2)" "source_tables_for_export_to_s3"
columnlist="$1"
tablelist="$2"
columncomma=""
headercomma=""
resultset=""
for i in $columnlist
do
rawcolumn=$i
case "$i" in 
*"("*)
rawcolumn=`echo $i | cut -d "(" -f2 | cut -d ")" -f1`;;
esac
resultset="$resultset, $rawcolumn"
headercomma="$headercomma, \'$rawcolumn\' AS $rawcolumn"
columncomma="$columncomma, CAST($i AS varchar(8000)) AS $rawcolumn"
done
echo "SELECT${resultset#?} FROM ( SELECT 1 as i$headercomma UNION ALL SELECT 2 AS i$columncomma FROM $tablelist ) t ORDER BY i"
