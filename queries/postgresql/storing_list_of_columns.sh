#Version 0.02: 1st Draft Version. Handy cookie cutter template within Bash for:
#1.Picking all the columns within a table in a comma delimited list for T-SQL insert statement. That is due to use cases, such as a table with a fabricated primary key (i.e. surrogate key), requires to explicitly state all the columns
#2.Picking all the (composite) primary keys within a table stored in an array. That is due to a more efficient way to calculate the difference between same dimension of tables at different timestamps that represent low volume of changes in set time intervals of existing past records. INNER JOIN SRC for finding existing records. LEFT JOIN SRC...WHERE SRC.X IS NULL for finding new records. Either type of join requires relationship of columns to be joined from one table to another, making a loop within an array containing the columns, a solution to generate the prerequisite words.
#3.Picking all the non primary keys and stored in an array, consumed only if array is not empty. Consumption use cases of such list can be: Used to update existing records. Yhat statement becomes true when its validated by one of the use cases explained by using the list of primary keys listed in point #2. Use cases of tables that have empty list of non-pk columns is valid and beneficial, such as placing those pk columns in an artificial table to be referenced (simplifying the equation) instead by an artificial pk (i.e. surrogate key) which results in faster joins as there is less data in order to reference the same data.

#1. All columns within the table comma delimited
ALLCOLUMNS=$(psql -U <<USERNAME>> -h <<SERVER>> -t -p <<PORT>> -d <<DATABASE>> -c "
   SELECT a.attname

   FROM      pg_class     c

   LEFT JOIN pg_attribute a
   ON a.attrelid  = c.oid

   LEFT JOIN pg_namespace p
   ON p.oid       = c.relnamespace

   LEFT JOIN pg_index i
   ON i.indrelid = a.attrelid

   WHERE  a.attnum    > 0
   AND    p.nspname   = '<<SCHEMA_NAME>>'
   AND    c.relname   = '<<DATABASE_NAME>>'

   ORDER BY a.attnum;
")

ALLCOLUMNS=${ALLCOLUMNS// /,}
ALLCOLUMNS=${ALLCOLUMNS:1}

echo $ALLCOLUMNS

#2. Picking all the (composite) primary keys within a table stored in an array
PKCOLUMNS=$(psql -U <<USERNAME>> -h <<SERVER>> -t -p <<PORT>> -d <<DATABASE>> -c"
   SELECT a.attname

   FROM      pg_class     c

   LEFT JOIN pg_attribute a
   ON a.attrelid  = c.oid

   LEFT JOIN pg_namespace p
   ON p.oid       = c.relnamespace

   LEFT JOIN pg_index i
   ON i.indrelid = a.attrelid

   WHERE  a.attnum    > 0
   AND    p.nspname   = '<<SCHEMA_NAME>>'
   AND    c.relname   = '<<DATABASE_NAME>>'
   AND    i.indisprimary

   ORDER BY a.attnum;
")

PKCOLUMNS=${PKCOLUMNS// /,}
PKCOLUMNS=${PKCOLUMNS:1}
IFS=','
pkarray=($PKCOLUMNS)

#3. Picking all the non primary keys within a table stored in an array. Put conditional statement to not consume if non-primary key list is empty.
NOPKCOLUMNS=$(psql -U <<USERNAME> -h <<SERVER>> -t -p <<PORT>> -d <<DATABASE>> -c"
   SELECT a.attname
   FROM      pg_class     c
   LEFT JOIN pg_attribute a
   ON a.attrelid  = c.oid
   LEFT JOIN pg_namespace p
   ON p.oid       = c.relnamespace
   LEFT JOIN pg_index i
   ON i.indrelid = a.attrelid
   WHERE  a.attnum    > 0
   AND    p.nspname   = '<<SCHEMA_NAME>>'
   AND    c.relname   = '<<DATABASE_NAME>>'
   AND    NOT (i.indisprimary)
   ORDER BY a.attnum;
")
NOPKCOLUMNS=${NOPKCOLUMNS// /,}
NOPKCOLUMNS=${NOPKCOLUMNS:1}
IFS=','
nopkarray=($NOPKCOLUMNS)
if [[ ${#nopkarray[@]} > 0 ]]; then
echo ${#nopkarray[@]}
else
echo "non-primary keys not found within relation"
fi
