USE [arts];
GO

-- =========================================
-- CONFIGURATION — edit only this section
-- =========================================
DECLARE @publisherDB    NVARCHAR(128) = N'arts';          -- ↑ CHANGE: database to replicate from
DECLARE @pubName        NVARCHAR(128) = N'artsRepl';      -- ↑ CHANGE: publication name
DECLARE @dbSchema       NVARCHAR(128) = N'arts';          -- ↑ CHANGE: schema of source tables
DECLARE @password       NVARCHAR(128) = N'Poste@2025';    -- ↑ CHANGE: agent accounts password
DECLARE @SnapshotLogin  SYSNAME = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) + N'\repl_snapshot';   -- ↑ CHANGE: suffix if different
DECLARE @LogReaderLogin SYSNAME = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) + N'\repl_logreader';  -- ↑ CHANGE: suffix if different

-- =========================================
-- STEP 1: ENABLE PUBLISHING ON SOURCE DB
-- =========================================
EXEC sp_replicationdboption
    @dbname  = @publisherDB,
    @optname = N'publish',
    @value   = N'true';

-- =========================================
-- STEP 2: CREATE PUBLICATION
-- =========================================
EXEC sp_addpublication
    @publication       = @pubName,
    @status            = N'active',
    @sync_method       = N'concurrent',
    @allow_push        = N'true',
    @allow_pull        = N'true',
    @independent_agent = N'true',
    @immediate_sync    = N'true',
    @repl_freq         = N'continuous';

-- =========================================
-- STEP 3: SNAPSHOT AGENT
-- =========================================
EXEC sp_addpublication_snapshot
    @publication    = @pubName,
    @frequency_type = 1,
    @job_login      = @SnapshotLogin,
    @job_password   = @password;

-- =========================================
-- STEP 4: LOG READER AGENT
-- =========================================
EXEC sp_changelogreader_agent
    @job_login    = @LogReaderLogin,
    @job_password = @password;

-- =========================================
-- STEP 5: ADD ARTICLES (ALL USER TABLES)
-- To replicate specific tables only:
--   WHERE is_ms_shipped = 0 AND name IN ('Table1','Table2')
-- =========================================
DECLARE @ArticleName SYSNAME;

DECLARE article_cursor CURSOR FOR
    SELECT name FROM sys.tables
    WHERE  is_ms_shipped = 0
    ORDER BY name;

OPEN article_cursor;
FETCH NEXT FROM article_cursor INTO @ArticleName;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sp_addarticle
        @publication   = @pubName,
        @article       = @ArticleName,
        @source_owner  = @dbSchema,
        @source_object = @ArticleName,
        @type          = N'logbased';

    FETCH NEXT FROM article_cursor INTO @ArticleName;
END;

CLOSE article_cursor;
DEALLOCATE article_cursor;

-- =========================================
-- STEP 6: START SNAPSHOT JOB
-- =========================================
EXEC sp_startpublication_snapshot
    @publication = @pubName;
GO