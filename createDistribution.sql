USE [master];

-- =========================================
-- PARAMETERS
-- =========================================
DECLARE @Distributor SYSNAME = @@SERVERNAME;
DECLARE @DistributionDB SYSNAME = 'DistDB';
DECLARE @SnapshotFolder NVARCHAR(4000) = '\\' + CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) + '\ReplData';
DECLARE @Password NVARCHAR(255) = 'Str0ng!Pass_2026';

-- =========================================
-- GET PATHS (FIXED CAST)
-- =========================================
DECLARE @DataFolder NVARCHAR(4000);
DECLARE @LogFolder NVARCHAR(4000);

SELECT 
    @DataFolder = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(4000)),
    @LogFolder  = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(4000));

-- Fallback if NULL
IF @DataFolder IS NULL OR @LogFolder IS NULL
BEGIN
    SELECT 
        @DataFolder = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
    FROM sys.master_files
    WHERE database_id = 1 AND type = 0;

    SELECT 
        @LogFolder = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
    FROM sys.master_files
    WHERE database_id = 1 AND type = 1;
END;

-- =========================================
-- STEP 1: ADD DISTRIBUTOR
-- =========================================
EXEC sp_adddistributor 
    @distributor = @Distributor,
    @password = @Password;

-- =========================================
-- STEP 2: CREATE DISTRIBUTION DB
-- =========================================
EXEC sp_adddistributiondb 
    @database = @DistributionDB,
    @data_folder = @DataFolder,
    @log_folder = @LogFolder;

-- =========================================
-- STEP 3: ADD PUBLISHER
-- =========================================
EXEC sp_adddistpublisher 
    @publisher = @Distributor,
    @distribution_db = @DistributionDB,
    @working_directory = @SnapshotFolder,
    @security_mode = 1;
