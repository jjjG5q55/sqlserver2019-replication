USE [arts];
GO

-- =========================================
-- CONFIGURATION — edit only this section
-- =========================================
DECLARE @pubName   NVARCHAR(128) = N'artsRepl';      -- ↑ CHANGE: must match publication name
DECLARE @subHost   NVARCHAR(128) = N'SRVDB2';         -- ↑ CHANGE: subscriber hostname
DECLARE @subDB     NVARCHAR(128) = N'ReplDB';         -- ↑ CHANGE: subscriber target database
DECLARE @agentPass NVARCHAR(128) = N'Poste@2025';     -- ↑ CHANGE: Distribution Agent password
DECLARE @subLogin  NVARCHAR(128) = N'sa';             -- ↑ CHANGE: SQL login on subscriber
DECLARE @subPass   NVARCHAR(128) = N'P@ssw0rd';       -- ↑ CHANGE: subscriber SQL login password
DECLARE @distLogin SYSNAME = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) + N'\repl_distribution';  -- ↑ CHANGE: suffix if different

-- =========================================
-- STEP 1: CREATE PUSH SUBSCRIPTION
-- =========================================
EXEC sp_addsubscription
    @publication       = @pubName,
    @subscriber        = @subHost,
    @destination_db    = @subDB,
    @subscription_type = N'Push',
    @sync_type         = N'automatic';

-- =========================================
-- STEP 2: CREATE DISTRIBUTION AGENT JOB
-- =========================================
EXEC sp_addpushsubscription_agent
    @publication              = @pubName,
    @subscriber               = @subHost,
    @subscriber_db            = @subDB,
    @job_login                = @distLogin,
    @job_password             = @agentPass,
    @subscriber_security_mode = 0,       -- 0 = SQL Auth | 1 = Windows Auth
    @subscriber_login         = @subLogin,
    @subscriber_password      = @subPass,
    @frequency_type           = 64;      -- 64 = run continuously
GO