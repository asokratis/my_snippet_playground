SELECT filename, string_agg(thecontent, chr(10)) as thecontent FROM
(
SELECT   p.nspname || '_' || c.relname || '.json' AS filename,
         CASE WHEN a.attnum = 1 THEN '[' || chr(10) ELSE '' END
         || '{"name":"' || upper(a.attname) || '", "type":"' ||
         CASE WHEN position('character varying' in format_type(a.atttypid, a.atttypmod)) = 1 OR
                   position('text'              in format_type(a.atttypid, a.atttypmod)) = 1 THEN 'STRING'
              WHEN position('numeric'           in format_type(a.atttypid, a.atttypmod)) = 1 THEN 'FLOAT'
              WHEN position('date'              in format_type(a.atttypid, a.atttypmod)) = 1 THEN 'DATE'
              WHEN position('timestamp'         in format_type(a.atttypid, a.atttypmod)) = 1 THEN 'TIMESTAMP'
              WHEN position('bigint'            in format_type(a.atttypid, a.atttypmod)) = 1 OR
                   position('smallint'          in format_type(a.atttypid, a.atttypmod)) = 1 THEN 'INTEGER'
              ELSE upper(format_type(a.atttypid, a.atttypmod)) END || '"}' || 
              CASE WHEN MAX(a.attnum) OVER (PARTITION BY p.nspname, c.relname) <> a.attnum THEN ',' ELSE chr(10) || ']'  END AS thecontent
   FROM      pg_class     c
   LEFT JOIN pg_attribute a
   ON a.attrelid  = c.oid
   LEFT JOIN pg_namespace p
   ON p.oid       = c.relnamespace
   LEFT JOIN pg_index i
   ON i.indrelid = a.attrelid
   WHERE  a.attnum    > 0
   AND    p.nspname   = '<SCHEMA_NAME>'
   AND    c.relname   IN ('<TABLE_NAME>')
   ORDER BY p.nspname, c.relname, a.attnum
) src
group by src.filename
order by src.filename
