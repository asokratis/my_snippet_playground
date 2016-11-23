--Credits: http://dba.stackexchange.com/a/119875 by gsiems (http://dba.stackexchange.com/users/6393/gsiems)
SELECT 'CREATE ' 
            || CASE
                WHEN i.indisunique THEN 'UNIQUE '
                ELSE ''
                END
            || 'INDEX '
            || nr.nspname
            || '.'
            || c2.relname
            || ' ON '
            || nr.nspname
            || '.'
            || c.relname
            || ' ( '
            || split_part ( split_part ( pg_catalog.pg_get_indexdef ( i.indexrelid, 0, true ), '(', 2 ), ')', 1 )
            || ' ); '
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_index i
        ON ( c.oid = i.indrelid )
    JOIN pg_catalog.pg_class c2
        ON ( i.indexrelid = c2.oid )
    JOIN pg_namespace nr
        ON ( nr.oid = c.relnamespace )
    --Migrate indexes from which schema?
    WHERE nr.nspname = '<SCHEMA_NAME>' AND
    --What tables indexes within schema specified to not migrate?
    NOT(c.relname like 'TABLE_NAME%')    
