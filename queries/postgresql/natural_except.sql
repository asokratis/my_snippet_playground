--Function: Natural Except - Updating original table based on changes from new table including null values (delete and then insert from resultset based by PK)
--Motivation: Because "Except" statements are not supported in some other db environments
--Current query can generate for only one table at a time
with table_list as (select '<SCHEMA_NAME>.<TABLE_NAME>' as list)       
SELECT string_agg(print,chr(10)) FROM
(
   SELECT 'SELECT t1.*' AS print
   UNION ALL
   --move "_new" postfix from t2 to t1 for updating original table on records that do not exist anymore (delete from resultset based by PK)
   SELECT '   FROM '      || list::varchar || ' t1'     FROM table_list 
   UNION ALL
   SELECT '   LEFT JOIN ' || list::varchar || '_new t2' FROM table_list
   UNION ALL
   --Assuming table has no pk explicitly defined but implicitly known its position. Otherwise, replace condition to "i.indisprimary"
   SELECT CASE WHEN a.attnum = 1   THEN '   ON  t1.'   || a.attname || ' = t2.' || a.attname 
                                   ELSE '   AND ((t1.' || a.attname || ' = t2.' || a.attname  || ') OR (t1.' || a.attname || ' IS NULL AND t2.' || a.attname || ' IS NULL))' END   
   FROM      pg_class     c
   LEFT JOIN pg_attribute a
   ON a.attrelid  = c.oid
   LEFT JOIN pg_namespace p
   ON p.oid       = c.relnamespace
   LEFT JOIN pg_index i
   ON i.indrelid = a.attrelid
   WHERE  a.attnum    > 0
   AND    (p.nspname || '.' || c.relname)   = (select list::varchar from table_list)
   UNION ALL
   SELECT '   WHERE t2.' || a.attname || ' IS NULL '   
   FROM      pg_class     c
   LEFT JOIN pg_attribute a
   ON a.attrelid  = c.oid
   LEFT JOIN pg_namespace p
   ON p.oid       = c.relnamespace
   WHERE  a.attnum    = 1
   AND    (p.nspname || '.' || c.relname)   = (select list::varchar from table_list)
   ) src
