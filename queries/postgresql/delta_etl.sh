# If table "x_new" is the new table and "x" is the existing table, We create the delta as "delta_x" while replacing "x" with "x_new" after that.
# Example: sh delta_etl.sh "column_1 column_2" "table_name" "schema_name" 
columnlist="$1"
tablename="$2"
schemaname="$3"
resultset=""
for i in $columnlist 
do
resultset="$resultset, $i" 
done

echo "DROP TABLE IF EXISTS ${schemaname}.delta_${tablename}; CREATE TABLE ${schemaname}.delta_${tablename} AS ( SELECT ${resultset#?} from ${schemaname}.${tablename}_new EXCEPT SELECT ${resultset#?} from ${schemaname}.${tablename} ); DROP TABLE IF EXISTS ${schemaname}.${tablename}; ALTER TABLE ${schemaname}.${tablename}_new RENAME TO ${tablename};"
