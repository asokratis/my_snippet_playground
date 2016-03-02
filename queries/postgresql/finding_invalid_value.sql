--Logs
--Version 0.01 Read description for more info. Made it compatible for Redshift. Amendments later will be done to make it compatible for native Postgresql.

--Description
--Tables with Columns Containing Invalid Character
--You Do: Input the invalid character. Input the table names (along their schema name) to check if that invalid character exists in any of the columns with the appropriate data type we also define based on our input.
--You Get: A list of the tables that show for each table a list of columns that contain the invalid character delimited by a comma. If the list of columns is empty, no column within that table has the invalid character
DROP TABLE IF EXISTS temp_table_metadata;
DROP TABLE IF EXISTS tmp_important_metadata;

CREATE TEMPORARY TABLE temp_table_metadata AS (
SELECT
      substring(p.nspname,1,999)::varchar(999)      AS theschemaname,
      substring(c.relname,1,999)::varchar(999)      AS thetablename,
      a.attnum::bigint                              AS ordinalposition,
      substring(a.attname,1,999)::varchar(999)      AS thecolumnname,
      '<INPUT_VALUE_TO_FIND>'                       AS invalidcharacter -- case insensitive

   FROM
   pg_class     c,
   pg_attribute a,
   pg_type      t,
   pg_namespace p

   WHERE
         --START <INPUT CONDITION: ACCEPTABLE DATA TYPE COLUMNS TO COMPARE WITH INVALIDCHARACTER>
         --Enter here columns w\ bellow data types accepted for comparison (use case example bellow: datatypes that we store string values)
         (
         position('varchar' in lower(substring(t.typname,1,999))) <> 0 OR
         position('text' in lower(substring(t.typname,1,999)))    <> 0
         ) AND
         --END
         a.attnum    > 0
     AND a.attrelid  = c.oid
     AND a.atttypid  = t.oid
     AND p.oid       = c.relnamespace
     --START <INPUT CONDITION: LIST THE TABLE NAMES YOU WANT TO COMPARE BELLOW>
     -- Hint 1: You can add multiple schemas or table names in here, this just an "example"
     -- Hint 2: Keep a small list if database aggregations are slow or tables are too big
     AND p.nspname    = '<INPUT_SCHEMA_NAME>'
     AND (
          c.relname   = '<INPUT_TABLE_SAMPLE_A>'   OR
          c.relname   = '<INPUT_TABLE_SAMPLE_B>'
         )
     --END
);

CREATE TEMPORARY TABLE tmp_important_metadata AS (
SELECT
      theschemaname,
      thetablename,
      ROW_NUMBER() OVER (PARTITION BY 1 ORDER BY theschemaname, thetablename) AS R

   FROM temp_table_metadata

   GROUP BY theschemaname, thetablename
);

SELECT output FROM (
(
SELECT
      R,
      1 AS priority,
      CASE WHEN R = 1 THEN '(' ELSE ' UNION ALL (' END + 'SELECT '''+theschemaname+'.'+thetablename+''' as thetable, '''' '  AS OUTPUT

   FROM tmp_important_metadata
)
UNION ALL
(
SELECT
      h.R,
      2 AS priority,
      '+MAX(CASE WHEN position('''+invalidcharacter+''' in lower('+thecolumnname+')) <> 0 THEN '','+thecolumnname+''' ELSE '''' END)' AS  OUTPUT

   FROM       temp_table_metadata    AS d

   INNER JOIN  tmp_important_metadata AS h
   ON  d.theschemaname = h.theschemaname
   AND d.thetablename  = h.thetablename
)
UNION ALL
(
SELECT
      R,
      3 AS priority,
      'AS OUTPUT FROM '+theschemaname+'.'+thetablename +')' AS OUTPUT

   FROM tmp_important_metadata
)
) SRC
ORDER BY R, priority
