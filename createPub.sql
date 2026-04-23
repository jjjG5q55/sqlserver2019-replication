
-- USE is handled dynamically via @PublisherDB
-- =============================================
-- CONFIGURATION — edit only this section
-- =============================================
DECLARE @PublisherDB SYSNAME = 'ReplicationTestDB'; -- Change if using existing DB
DECLARE @MachineName    NVARCHAR(128) = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128));
DECLARE @SnapshotLogin  SYSNAME = @MachineName + '\repl_snapshot';
DECLARE @LogReaderLogin SYSNAME = @MachineName + '\repl_logreader';

DECLARE @Password NVARCHAR(255) = 'Poste@2025';

-- =========================================
-- STEP 1: ENABLE PUBLISHING
-- =========================================
EXEC sp_replicationdboption 
    @dbname = @PublisherDB,
    @optname = 'publish',
    @value = 'true';

-- =========================================
-- STEP 2: CREATE PUBLICATION
-- =========================================
EXEC sp_addpublication
    @publication = @Publication,
    @status = 'active',
    @sync_method = 'concurrent',
    @allow_push = 'true',
    @allow_pull = 'true',
    @independent_agent = 'true',
    @immediate_sync = 'true',
    @repl_freq = 'continuous';

-- =========================================
-- STEP 3: SNAPSHOT AGENT (WITH YOUR ACCOUNT)
-- =========================================
EXEC sp_addpublication_snapshot
    @publication = @Publication,
    @frequency_type = 1,
    @job_login = @SnapshotLogin,
    @job_password = @Password;

-- =========================================
-- STEP 4: LOG READER AGENT (UPDATE EXISTING)
-- =========================================
EXEC sp_changelogreader_agent
    @job_login = @LogReaderLogin,
    @job_password = @Password;

-- =========================================
-- STEP 5: ADD ALL TABLES
-- =========================================
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql + '
EXEC sp_addarticle
    @publication = ''' + @Publication + ''',
    @article = ''' + t.name + ''',
    @source_owner = ''dbo'',
    @source_object = ''' + t.name + ''',
    @type = ''logbased'';
'
FROM sys.tables t
WHERE is_ms_shipped = 0;

EXEC sp_executesql @sql;

-- =========================================
-- STEP 6: START SNAPSHOT
-- =========================================
EXEC sp_startpublication_snapshot 
    @publication = @Publication;
GO
