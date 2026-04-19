USE [master];
GO

-- =========================================
-- PARAMETERS
-- =========================================
DECLARE @Distributor SYSNAME = @@SERVERNAME;
DECLARE @DistributionDB SYSNAME = 'DistDB';
DECLARE @SnapshotFolder NVARCHAR(4000) = '\\' + @@SERVERNAME + '\ReplData';
DECLARE @Password NVARCHAR(255) = 'Str0ng!Pass_2026';

-- =========================================
-- GET INSTANCE DEFAULT PATHS (REPLACED LOGIC)
-- =========================================
DECLARE @DataFolder NVARCHAR(4000);
DECLARE @LogFolder NVARCHAR(4000);

SELECT 
    @DataFolder = SERVERPROPERTY('InstanceDefaultDataPath'),
    @LogFolder  = SERVERPROPERTY('InstanceDefaultLogPath');

-- Fallback if NULL (common on some installs)
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
END

-- =========================================
-- STEP 1: ADD DISTRIBUTOR
-- =========================================
EXEC sp_adddistributor 
    @distributor = @Distributor,
    @password = @Password;
GO

-- =========================================
-- STEP 2: CREATE DISTRIBUTION DB (DYNAMIC PATHS)
-- =========================================
EXEC sp_adddistributiondb 
    @database = 'DistDB',
    @data_folder = @DataFolder,
    @log_folder  = @LogFolder;
GO

-- =========================================
-- STEP 3: REGISTER PUBLISHER
-- =========================================
EXEC sp_adddistpublisher 
    @publisher = @@SERVERNAME,
    @distribution_db = 'DistDB',
    @working_directory = '\\' + @@SERVERNAME + '\ReplData',
    @security_mode = 1;
GO
