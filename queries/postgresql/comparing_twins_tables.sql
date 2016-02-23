--Version 0.01: This is an initial draft. Fits for some of my use case requirements. Will add more later to make this more robust, handle more use cases.
--Requirements: Latest Postgresql environment

--Configurations on "temp_table_metadata" (Replace and fill in the text with prefix "INPUT_")
CREATE TEMPORARY TABLE temp_table_metadata AS (
SELECT
      substring(p.nspname,1,999)      AS theschemaname, --currently, both sibling tables are expected to be in both schema (i.e. put both sibling tables in a testing schema for testing purposes)
      substring(c.relname,1,999)      AS thetablename,
      a.attnum                        AS ordinalposition,
      substring(a.attname,1,999)      AS thecolumnname,
      substring(t.typname,1,999)      AS thedatatype,
      '<INPUT_SECOND_SIBLING_TABLE>'  AS secondtable,
      CASE WHEN substring(a.attname,1,999) = '<INPUT_PRIMARY_KEY>' THEN 1 ELSE 0 END AS is_pk,
      CASE WHEN position('int'       in lower(substring(t.typname,1,999))) <> 0 THEN '-1'
           WHEN position('numeric'   in lower(substring(t.typname,1,999))) <> 0 THEN '-1.00'
           WHEN position('timestamp' in lower(substring(t.typname,1,999))) <> 0 THEN '''2001-01-01''::timestamp'
           --char for all other cases?
           ELSE ''';''' END           AS nulloutput,
      '<INPUT_UPDATED_COLUMN>'        AS updatedatcolumn --optional

   FROM
   pg_class     c,
   pg_attribute a,
   pg_type      t,
   pg_namespace p

   WHERE
         a.attnum    > 0
     AND a.attrelid  = c.oid
     AND a.atttypid  = t.oid
     AND p.oid       = c.relnamespace
     AND p.nspname   = '<INPUT_SCHEMA_NAME>'
     AND c.relname   = '<INPUT_FIRST_SIBLING_TABLE>'
);

CREATE TEMPORARY TABLE tmp_important_metadata AS (
SELECT
      thecolumnname AS primarykey,
      theschemaname,
      thetablename,
      secondtable,
      updatedatcolumn

   FROM temp_table_metadata

   WHERE is_pk = 1
);

--QUERY #1: COLUMNS DIFFERENCE WITHIN 2 SIBLING TABLES JOINED BY PRIMARY KEY
--Note 1: Assuming thetablename (f) column updatedatcolumn is smaller than secondtable (s) column updatedatcolumn (if no updatedatcolumn, we assume first table is less recent or equal recent to second table implicitly)
--Note 2: Compares only records that were not new by the secondtable (How many they do not exist can be found within column "diff_no_instances" of query #2
--Note 3: Compares only records that were not new + existing records not updated since thetablename time recency: Remove comments lines (Requires updatedatcolumn - How many additionally are opted out, check column "diff_no_instances_noupdate" of query #2)
SELECT output FROM
(
(SELECT -2               as prec,'SELECT COUNT(*) AS total_instances' AS output)
UNION ALL
(SELECT -1               as prec,',COUNT(s.' + (SELECT primarykey FROM tmp_important_metadata) + ') AS second_table_instances ')
UNION ALL
(SELECT  0               as prec,',((COUNT(s.' + (SELECT primarykey FROM tmp_important_metadata) + ')/COUNT(*)::decimal)*100)::decimal(10,4) AS perc_second_table_instances ')
UNION ALL
(
SELECT   ordinalposition as prec,',ABS(COUNT(CASE WHEN COALESCE(f.' + thecolumnname + ',' + nulloutput + ') = COALESCE(s.' + thecolumnname + ',' + nulloutput + ') THEN TRUE END) - COUNT(*)) AS ' + thecolumnname  as output
FROM  temp_table_metadata
WHERE is_pk = 0
)
UNION ALL
(
SELECT (ordinalposition + 2000) as prec,',((ABS(COUNT(CASE WHEN COALESCE(f.' + thecolumnname + ',' + nulloutput + ') = COALESCE(s.' + thecolumnname + ',' + nulloutput + ') THEN TRUE END) - COUNT(*))/COUNT(*)::decimal)*100)::decimal(10,4) AS perc_' + thecolumnname  as output
FROM  temp_table_metadata
WHERE is_pk = 0
)
UNION ALL
(SELECT   9001            as prec,' FROM '      + theschemaname + '.' + thetablename + ' f ' as output FROM tmp_important_metadata)
UNION ALL
(SELECT   9002            as prec,' LEFT JOIN ' + theschemaname + '.' + secondtable  + ' s ' as output FROM tmp_important_metadata)
UNION ALL
(SELECT   9003            as prec,' ON f.' + primarykey + '= s.' + primarykey                as output FROM tmp_important_metadata)
UNION ALL
(SELECT   9004            as prec, '-- WHERE s.' + updatedatcolumn + '<= (SELECT MAX(' + updatedatcolumn + ') as updated_at FROM  ' + theschemaname + '.' + thetablename + ' )' as output FROM tmp_important_metadata)
)
ORDER BY prec;

--QUERY #2: GENERAL STATS OF THE DIFFERENCE WITHIN RECORDS OF 2 SIBLING TABLES IN TERMS OF PRIMARY KEY
--Commented lines is used If updatedatcolumn is available: It will be more transparent to assume what is the maximum expected range of values each column can be changed up to.
--WARNING 1: These numbers are correct assuming the debug passed correctly or can be explained within good nature why the debug failed. Otherwise, the numbers in here will be skewed - see comments of "DEBUG" section)
--WARNING 2: Commented out queries that need the updatedatcolumn as most tables may not contain that.
--WARNING 3: The debug only makes sense when the primary key is numeric and its value within the new record inserted by default is of greater value than of any records primary key existed before it.
--diff_no_instances: New records that never existed on the old table
--diff_no_instances_noupdate: Existing records that exist on the old table as well, but they are updated, so its expected they changed
--total number of records that expect to be different: diff_no_instances + diff_no_instances_noupdate
--total number of records that expect to be different in terms of percentage: diff_perc_instances + diff_perc_instances_noupdate
--DEBUG
--Debug columns: second_maxid (secondtable) - first_id (thetablename) = diff_no_id,
--Debug conditions: diff_no_id = diff_no_instances, diff_perc_id ~= diff_perc_instances.
--If any debug conditions false, then there may be chances these missing records due to
--A. Bad Nature: failed incremental load
--B. Good Nature: physically deleted records on the original source of the table done intentionally or due to data fix.
--C. To prove that it was by bad nature 100%, run query "Incremental by BAD NATURE?"
SELECT
'
SELECT first_instances, second_instances, diff_no_instances, diff_no_instances_noupdate, diff_perc_instances, diff_perc_instances_noupdate, second_maxid, first_maxid, diff_no_id, diff_perc_id from (
SELECT
        MAX(CASE WHEN caption = ''f'' THEN instances END)                                                                                               AS first_instances
       ,MAX(CASE WHEN caption = ''s'' THEN instances END)                                                                                               AS second_instances
       ,MAX(CASE WHEN caption = ''s'' THEN instances END) - MAX(CASE WHEN caption = ''f'' THEN instances END)                                           AS diff_no_instances
       ,100.00 - ROUND((MAX(CASE WHEN caption = ''f'' THEN instances END)::decimal / MAX(CASE WHEN caption = ''s'' THEN instances END)) * 100,4)        AS diff_perc_instances
       ,MAX(  CASE WHEN caption = ''f'' THEN maxid END)                                                                                                 AS first_maxid
       ,MAX(  CASE WHEN caption = ''s'' THEN maxid END)                                                                                                 AS second_maxid
       ,MAX(  CASE WHEN caption = ''s'' THEN maxid END) - MAX(CASE WHEN caption = ''f'' THEN maxid END)                                                 AS diff_no_id
       ,100.00 - ((MAX(CASE WHEN caption = ''f'' THEN maxid END)::decimal / MAX(CASE WHEN caption = ''s'' THEN maxid END)) * 100)::decimal(10,4)        AS diff_perc_id
       -- ,MAX(CASE WHEN caption = ''t'' THEN instances END)                                                                                            AS third_instances
       -- ,MAX(CASE WHEN caption = ''f'' THEN instances END) - MAX(CASE WHEN caption = ''t'' THEN instances END)                                        AS diff_no_instances_noupdate
       -- ,100.00 - ROUND((MAX(CASE WHEN caption = ''t'' THEN instances END)::decimal / MAX(CASE WHEN caption = ''f'' THEN instances END)) * 100,4)     AS diff_perc_instances_noupdate
   FROM
   (
    SELECT ''f'' as caption, COUNT(*) AS instances, MAX('+primarykey+') AS maxid, MAX('+updatedatcolumn+') as updated_at FROM '+theschemaname+'.'+thetablename+' f
    UNION ALL
    SELECT ''s'' as caption, COUNT(*) AS instances, MAX('+primarykey+') AS maxid, MAX('+updatedatcolumn+') as updated_at FROM '+theschemaname+'.'+secondtable+'  s
    -- UNION ALL
    -- SELECT ''t'' as caption, COUNT(*) AS instances, MAX('+primarykey+') AS maxid, MAX('+updatedatcolumn+') as updated_at FROM '+theschemaname+'.'+secondtable+'  s
    -- WHERE updated_at <= (SELECT MAX('+updatedatcolumn+') as updated_at FROM '+theschemaname+'.'+thetablename+' f)
    )
)
'  AS OUTPUT
   FROM tmp_important_metadata;

--QUERY #3: Incremental by BAD NATURE?
--Notes 1: Does not require updatedatcolumn column
--Notes 2: secondtableinstances - firsttableinstances = Records missed to insert within incremental load.
SELECT
'
SELECT count(*) as secondtableinstances, count('+thetablename+'.'+primarykey+') as firsttableinstances
FROM '+theschemaname+'.'+thetablename+'
LEFT JOIN '+theschemaname+'.'+secondtable+'
ON '+thetablename+'.'+primarykey+' = '+secondtable+'.'+primarykey+'
WHERE '+secondtable+'.'+primarykey+'  <= (SELECT MAX('+secondtable+'.'+primarykey+') FROM '+theschemaname+'.'+secondtable+')
'
 FROM tmp_important_metadata;
