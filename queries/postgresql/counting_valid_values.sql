--Logs
--Similar to postgresql/finding_invalid_value.sql, but instead find how many instances per column within table have values with no invalid character
--Practical usage is to count how many nulls exist within varchar columns for one specific table
--Query can be altered for other use cases (i.e. other data types like numeric values).
DROP TABLE IF EXISTS temp_table_metadata;
DROP TABLE IF EXISTS tmp_important_metadata;

CREATE TEMPORARY TABLE temp_table_metadata AS (
SELECT
      substring(p.nspname,1,999)::varchar(999)      AS theschemaname,
      substring(c.relname,1,999)::varchar(999)      AS thetablename,
      a.attnum::bigint                              AS ordinalposition,
      substring(a.attname,1,999)::varchar(999)      AS thecolumnname,
      '<INPUT_VALUE_TO_FIND>'::varchar(999)         AS invalidcharacter -- case insensitive

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
     --START <INPUT CONDITION: LIST THE TABLES - Note: Tables must have the same columns with the same data type>
     AND p.nspname    = '<INPUT_SCHEMA_NAME>'
     AND (
          c.relname   = '<INPUT_TABLE_SAMPLE_A>' OR c.relname  = '<INPUT_TABLE_SAMPLE_B>'
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
	  '' as thecolumnname,
      CASE WHEN R = 1 THEN '(' ELSE ' UNION ALL (' END || 'SELECT '''||theschemaname||'.'||thetablename||''' as thetable,'  AS OUTPUT

   FROM tmp_important_metadata
)
UNION ALL
(
SELECT
      h.R,
      2 AS priority,
	  thecolumnname,
      'SUM(CASE WHEN position('''||invalidcharacter||''' in lower(COALESCE('||thecolumnname||',''null''))) = 0 THEN 1 ELSE 0 END) AS '|| thecolumnname || ',
' AS  OUTPUT

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
	  '' as thecolumnname,
      '0 AS ENDCOLUMN FROM '||theschemaname||'.'||thetablename ||')' AS OUTPUT

   FROM tmp_important_metadata
)
) SRC
ORDER BY R, priority, thecolumnname
