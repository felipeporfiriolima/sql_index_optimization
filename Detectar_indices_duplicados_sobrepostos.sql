/*
    Detectar índices duplicados / sobrepostos (SQL Server 2012+)

    Saídas:
      1) DUPLICATE_EXACT: KEY + INCLUDE + FILTER iguais
      2) DUPLICATE_KEYS_ONLY: mesma KEY + FILTER (INCLUDE pode variar) - lista índices via XML concat

    Observações:
      - Varrendo todos DBs online (exceto system dbs por padrão)
      - Ignora heaps (index_id = 0)
      - Considera índices filtrados (filter_definition)
*/

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..##IdxSig') IS NOT NULL DROP TABLE ##IdxSig;
CREATE TABLE ##IdxSig
(
    ServerName        sysname        NOT NULL DEFAULT @@SERVERNAME,
    DatabaseName      sysname        NOT NULL,
    SchemaName        sysname        NOT NULL,
    TableName         sysname        NOT NULL,
    ObjectId          int            NOT NULL,
    IndexId           int            NOT NULL,
    IndexName         sysname        NOT NULL,
    IndexTypeDesc     nvarchar(60)   NOT NULL,
    IsPrimaryKey      bit            NOT NULL,
    IsUnique          bit            NOT NULL,
    HasFilter         bit            NOT NULL,
    FilterDefinition  nvarchar(max)  NULL,

    KeyCols           nvarchar(max)  NOT NULL,   -- keys ordenadas, com ASC/DESC
    IncludeCols       nvarchar(max)  NULL,       -- includes ordenados
    KeySig            varbinary(32)  NOT NULL,   -- hash key + filtro
    FullSig           varbinary(32)  NOT NULL,   -- hash key + include + filtro

    _RowCount         bigint         NULL,
    ReservedMB        decimal(18,2)  NULL,
    UserSeeks         bigint         NULL,
    UserScans         bigint         NULL,
    UserLookups       bigint         NULL,
    UserUpdates       bigint         NULL
);

DECLARE @DynSql nvarchar(max) = N'';

;WITH DbList AS
(
    SELECT d.name
    FROM sys.databases d
    WHERE d.state_desc = 'ONLINE'
      AND d.database_id > 4       -- ignora master/model/msdb/tempdb
      AND d.is_read_only = 0
      -- AND d.name IN ('SeuBD1','SeuBD2') -- se quiser filtrar
)
SELECT @DynSql = @DynSql + N'
USE ' + QUOTENAME(name) + N';

;WITH IdxBase AS
(
    SELECT
        DB_NAME() AS DatabaseName,
        sc.name   AS SchemaName,
        ob.name   AS TableName,
        ob.object_id AS ObjectId,
        ix.index_id  AS IndexId,
        ix.name      AS IndexName,
        ix.type_desc AS IndexTypeDesc,
        ix.is_primary_key AS IsPrimaryKey,
        ix.is_unique      AS IsUnique,
        ix.has_filter     AS HasFilter,
        ix.filter_definition AS FilterDefinition
    FROM sys.indexes ix
    JOIN sys.objects ob ON ob.object_id = ix.object_id AND ob.type = ''U''
    JOIN sys.schemas sc ON sc.schema_id = ob.schema_id
    WHERE ix.index_id > 0
      AND ix.is_hypothetical = 0
),
IdxCols AS
(
    SELECT
        b.DatabaseName, b.SchemaName, b.TableName, b.ObjectId, b.IndexId, b.IndexName,
        b.IndexTypeDesc, b.IsPrimaryKey, b.IsUnique, b.HasFilter, b.FilterDefinition,

        KeyCols =
        STUFF((
            SELECT N'', '' + QUOTENAME(c.name) +
                   CASE WHEN ic.is_descending_key = 1 THEN N'' DESC'' ELSE N'' ASC'' END
            FROM sys.index_columns ic
            JOIN sys.columns c
              ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE ic.object_id = b.ObjectId
              AND ic.index_id  = b.IndexId
              AND ic.key_ordinal > 0
            ORDER BY ic.key_ordinal
            FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)'')
        ,1,2,N''''),

        IncludeCols =
        NULLIF(STUFF((
            SELECT N'', '' + QUOTENAME(c.name)
            FROM sys.index_columns ic
            JOIN sys.columns c
              ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE ic.object_id = b.ObjectId
              AND ic.index_id  = b.IndexId
              AND ic.is_included_column = 1
            ORDER BY ic.column_id
            FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)'')
        ,1,2,N''''), N'''')
    FROM IdxBase b
),
IdxSize AS
(
    SELECT
        ps.object_id,
        ps.index_id,
        _RowCount = SUM(ps.row_count),
        ReservedMB = CAST(SUM(ps.reserved_page_count) * 8.0 / 1024.0 AS decimal(18,2))
    FROM sys.dm_db_partition_stats ps
    GROUP BY ps.object_id, ps.index_id
),
IdxUse AS
(
    SELECT
        object_id, index_id,
        user_seeks, user_scans, user_lookups, user_updates
    FROM sys.dm_db_index_usage_stats
    WHERE database_id = DB_ID()
)
INSERT INTO ##IdxSig
(
    DatabaseName, SchemaName, TableName, ObjectId, IndexId, IndexName, IndexTypeDesc,
    IsPrimaryKey, IsUnique, HasFilter, FilterDefinition,
    KeyCols, IncludeCols, KeySig, FullSig,
    _RowCount, ReservedMB, UserSeeks, UserScans, UserLookups, UserUpdates
)
SELECT
    c.DatabaseName, c.SchemaName, c.TableName, c.ObjectId, c.IndexId, c.IndexName, c.IndexTypeDesc,
    c.IsPrimaryKey, c.IsUnique, c.HasFilter, c.FilterDefinition,
    c.KeyCols, c.IncludeCols,
    HASHBYTES(''SHA2_256'', CAST(CONCAT(c.KeyCols, N''|F='', ISNULL(c.FilterDefinition, N'''')) AS nvarchar(max))) AS KeySig,
    HASHBYTES(''SHA2_256'', CAST(CONCAT(c.KeyCols, N''|I='', ISNULL(c.IncludeCols, N''''), N''|F='', ISNULL(c.FilterDefinition, N'''')) AS nvarchar(max))) AS FullSig,
    s._RowCount, s.ReservedMB,
    u.user_seeks, u.user_scans, u.user_lookups, u.user_updates
FROM IdxCols c
LEFT JOIN IdxSize s ON s.object_id = c.ObjectId AND s.index_id = c.IndexId
LEFT JOIN IdxUse  u ON u.object_id = c.ObjectId AND u.index_id = c.IndexId
WHERE c.KeyCols IS NOT NULL AND c.KeyCols <> N'''';
'
FROM DbList;

EXEC sys.sp_executesql @DynSql;

--------------------------------------------------------------------------------
-- 1) Duplicados exatos (KEY + INCLUDE + FILTER iguais)
--------------------------------------------------------------------------------

SELECT
    Finding = 'Duplicidade Exata',
    DatabaseName, SchemaName, TableName,
    KeyCols, IncludeCols, 
    Indexes =
        STUFF((
            SELECT N' | ' + x2.IndexName
            FROM ##IdxSig x2
            WHERE x2.DatabaseName = x.DatabaseName
              AND x2.ObjectId     = x.ObjectId
              AND x2.FullSig      = x.FullSig
            ORDER BY x2.IndexName
            FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)')
        ,1,3,N''),
    TotalReservedMB = replace(SUM(ISNULL(ReservedMB,0)),'.',','),
    TotalUpdates = SUM(ISNULL(UserUpdates,0)),
    TotalReads   = SUM(ISNULL(UserSeeks,0) + ISNULL(UserScans,0) + ISNULL(UserLookups,0))
FROM ##IdxSig x
GROUP BY DatabaseName, SchemaName, TableName, ObjectId, FullSig, KeyCols, IncludeCols, FilterDefinition
HAVING COUNT(*) > 1
ORDER BY SUM(ISNULL(ReservedMB,0)) DESC, DatabaseName, SchemaName, TableName;

--------------------------------------------------------------------------------
-- 2) Duplicados por KEY (mesma KEY + FILTER) - INCLUDE pode variar
--------------------------------------------------------------------------------
SELECT
    DatabaseName, SchemaName, TableName,
    KeyCols,
    Indexes =
        STUFF((
            SELECT N' | ' + x2.IndexName +
                   CASE WHEN x2.IncludeCols IS NULL THEN N'' ELSE N' (inc: ' + x2.IncludeCols + N')' END
            FROM ##IdxSig x2
            WHERE x2.DatabaseName = x.DatabaseName
              AND x2.ObjectId     = x.ObjectId
              AND x2.KeySig       = x.KeySig
            ORDER BY x2.IndexName
            FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)')
        ,1,3,N''),
    TotalReservedMB = replace(SUM(ISNULL(ReservedMB,0)),'.',','),
    TotalUpdates = SUM(ISNULL(UserUpdates,0)),
    TotalReads   = SUM(ISNULL(UserSeeks,0) + ISNULL(UserScans,0) + ISNULL(UserLookups,0))
FROM ##IdxSig x
GROUP BY DatabaseName, SchemaName, TableName, ObjectId, KeySig, KeyCols, FilterDefinition
HAVING COUNT(*) > 1
ORDER BY SUM(ISNULL(ReservedMB,0)) DESC, DatabaseName, SchemaName, TableName;


 
