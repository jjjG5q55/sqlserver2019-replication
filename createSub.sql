
-- =============================================
-- CONFIGURATION — edit only this section
-- =============================================
DECLARE @Publication SYSNAME = 'RepTest_Pub';
DECLARE @Subscriber SYSNAME = 'SRVDB2';
DECLARE @SubscriberDB SYSNAME = 'ReplDB';
-- ADD to config block:
DECLARE @PublisherDB SYSNAME = 'ReplicationTestDB'; -- Change if using existing DB

DECLARE @SubLogin    SYSNAME       = 'sa';
DECLARE @SubPassword NVARCHAR(255) = 'P@ssw0rd';

DECLARE @MachineName NVARCHAR(128) = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128));
DECLARE @DistLogin   SYSNAME = @MachineName + '\repl_distribution';
DECLARE @DistPassword NVARCHAR(255) = 'Poste@2025';

-- =========================================
-- CREATE PUSH SUBSCRIPTION
-- =========================================

-- ADD before sp_addsubscription:
DECLARE @ctx NVARCHAR(MAX) = 'USE ' + QUOTENAME(@PublisherDB) + ';
EXEC sp_addsubscription
    @publication      = ''' + @Publication + ''',
    @subscriber       = ''' + @Subscriber + ''',
    @destination_db   = ''' + @SubscriberDB + ''',
    @subscription_type = ''Push'',
    @sync_type        = ''automatic'';';
EXEC sp_executesql @ctx;

-- =========================================
-- CREATE DISTRIBUTION AGENT JOB
-- (FIXED: NO distributor_security_mode here)
-- =========================================
EXEC sp_addpushsubscription_agent
    @publication = @Publication,
    @subscriber = @Subscriber,
    @subscriber_db = @SubscriberDB,

    -- Agent execution account
    @job_login = @DistLogin,
    @job_password = @DistPassword,

    -- Subscriber connection 
    @subscriber_security_mode = 0,
    @subscriber_login = @SubLogin,
    @subscriber_password = @SubPassword,

    -- Continuous execution
    @frequency_type = 64;
GO
