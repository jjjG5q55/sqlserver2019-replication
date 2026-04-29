USE [master];

DECLARE @distributerName     SYSNAME        = @@SERVERNAME;
DECLARE @distributerPassword NVARCHAR(128)  = N'Str0ng!Pass_2026';  -- ↑ CHANGE: strong password
DECLARE @distributerDb       NVARCHAR(128)  = N'DistDB';             -- ↑ CHANGE: distribution DB name
DECLARE @dataFolder          NVARCHAR(4000) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(4000));
DECLARE @logFolder           NVARCHAR(4000) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(4000));
DECLARE @workingDir          NVARCHAR(4000) = N'\\RTGS-TEST-WIN20\ReplData';  -- ↑ CHANGE: UNC snapshot share path

-- =========================================
-- STEP 1: ADD DISTRIBUTOR
-- =========================================
EXEC sp_adddistributor
    @distributor = @distributerName,
    @password    = @distributerPassword;

-- =========================================
-- STEP 2: CREATE DISTRIBUTION DATABASE
-- =========================================
EXEC sp_adddistributiondb
    @database    = @distributerDb,
    @data_folder = @dataFolder,
    @log_folder  = @logFolder;

-- =========================================
-- STEP 3: REGISTER PUBLISHER
-- =========================================
EXEC sp_adddistpublisher
    @publisher         = @distributerName,
    @distribution_db   = @distributerDb,
    @working_directory = @workingDir,
    @security_mode     = 1;  -- 1 = Windows Auth | 0 = SQL Auth
GO