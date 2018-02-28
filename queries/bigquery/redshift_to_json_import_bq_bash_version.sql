--The query in http://stackoverflow.com/a/21446650/4461267 was forked to create a redshift version of json create statement for bigquery
SELECT 'echo ''' || thecontent || ''' > ' || filename as thecontent FROM
(
select tm.schemaname || '_' || tm.tablename || '.json' AS filename,
 '[' || cp.coldef || ']' as thecontent
   from 
-- t  master table list
(
SELECT substring(n.nspname,1,500) as schemaname, substring(c.relname,1,500) as tablename, c.oid as tableid ,use2.usename as owner, decode(c.reldiststyle,0,'EVEN',1,'KEY',8,'ALL') as dist_style
FROM pg_namespace n, pg_class c,  pg_user use2 
WHERE n.oid = c.relnamespace 
  AND nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
  AND c.relname <> 'temp_staging_tables_1'
  and c.relowner = use2.usesysid
) tm 
-- cp  creates the col params for the create string
join
(select 
  substr(str,(charindex('QQQ',str)+3),(charindex('ZZZ',str))-(charindex('QQQ',str)+3)) as tableid
  ,substr(replace(replace(str,'ZZZ',''),'QQQ'||substr(str,(charindex('QQQ',str)+3),(charindex('ZZZ',str))-(charindex('QQQ',str)+3)),''),2,10000) as coldef
 from
 ( select array_to_string(array(
  SELECT  'QQQ'||cast(t.tableid as varchar(10))||'ZZZ'|| ','|| '{"name":"' ||column_name||'", "type":"' || 
   CASE WHEN       position('varchar' in decode(udt_name,'bpchar','char',udt_name)) = 1 OR
                   position('text'              in decode(udt_name,'bpchar','char',udt_name)) = 1 THEN 'STRING'
              WHEN position('numeric'           in decode(udt_name,'bpchar','char',udt_name)) = 1 OR
                   position('float'           in decode(udt_name,'bpchar','char',udt_name)) = 1 THEN 'FLOAT'
              WHEN position('date'              in decode(udt_name,'bpchar','char',udt_name)) = 1 THEN 'DATE'
              WHEN position('timestamp'         in decode(udt_name,'bpchar','char',udt_name)) = 1 THEN 'TIMESTAMP'
              WHEN position('bigint'            in decode(udt_name,'bpchar','char',udt_name)) = 1 OR
                   position('int'               in decode(udt_name,'bpchar','char',udt_name)) = 1 THEN 'INTEGER'
              ELSE upper(decode(udt_name,'bpchar','char',udt_name)) END || '"}' 

   as str 
   from  
  -- ci  all the col info
  (
    select cast(t.tableid as int), 
           cast(table_schema as varchar(500)), 
           cast(table_name as varchar(500)), 
           cast(column_name as varchar(500)), 
           cast(udt_name as varchar(500))  
    from 
    (select * from information_schema.columns c where  c.table_schema= t.schemaname and c.table_name=t.tablename) c
    left join 
    (-- gives sort cols
    select attrelid as tableid, attname as colname, attsortkeyord as sort_col_order from pg_attribute a where 
     a.attnum > 0  AND NOT a.attisdropped AND a.attsortkeyord > 0
    ) s on t.tableid=s.tableid and c.column_name=s.colname
    order by ordinal_position
  ) ci 
  -- for the working array funct
  ), '') as str
 from 
 (-- need tableid
 SELECT substring(n.nspname,1,500) as schemaname, substring(c.relname,1,500) as tablename, c.oid as tableid 
 FROM pg_namespace n, pg_class c
 WHERE n.oid = c.relnamespace 
 AND nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
 AND n.nspname = '<SCHEMA_NAME>' and c.relname in ('<TABLE_X>','<TABLE_Y>')
 ) t 
)) cp on tm.tableid=cp.tableid
) src
