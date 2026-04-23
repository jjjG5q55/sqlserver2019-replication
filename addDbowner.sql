USE [master];
GO

-- =========================
-- PARAMETERS
-- =========================
DECLARE @prefix NVARCHAR(128) = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128));
DECLARE @publisherDB SYSNAME = 'ReplicationTestDB';
DECLARE @DistributionDB SYSNAME = 'DistDB';
-- SET @prefix = 'MYDOMAIN'; -- if needed

DECLARE @databases TABLE (db SYSNAME);
INSERT INTO @databases VALUES
(@DistributionDB),
(@publisherDB);

DECLARE @accounts TABLE (name SYSNAME);
INSERT INTO @accounts VALUES
('repl_snapshot'),
('repl_logreader'),
('repl_distribution'),
('repl_merge');

-- =========================
-- PROCESS
-- =========================
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql + '
USE ' + QUOTENAME(d.db) + ';
PRINT ''--- Processing DB: ' + d.db + ' ---'';

' + (
    SELECT STRING_AGG(
'
IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals 
    WHERE name = ''' + @prefix + '\' + a.name + '''
)
BEGIN
    CREATE USER ' + QUOTENAME(@prefix + '\' + a.name) + ' 
    FOR LOGIN ' + QUOTENAME(@prefix + '\' + a.name) + ';
    PRINT ''User created: ' + @prefix + '\' + a.name + ''';
END

BEGIN TRY
    ALTER ROLE db_owner ADD MEMBER ' + QUOTENAME(@prefix + '\' + a.name) + ';
    PRINT ''Added to db_owner: ' + @prefix + '\' + a.name + ''';
END TRY
BEGIN CATCH
    PRINT ''Already in db_owner: ' + @prefix + '\' + a.name + ''';
END CATCH
'
, CHAR(10))
    FROM @accounts a
) + '
'
FROM @databases d;

-- =========================
-- EXECUTION
-- =========================
EXEC sp_executesql @sql;
GO
