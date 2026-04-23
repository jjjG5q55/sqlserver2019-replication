USE [ReplicationTestDB];
GO

DECLARE @Publication SYSNAME = 'RepTest_Pub';
DECLARE @Subscriber SYSNAME = 'SRVDB2';
DECLARE @SubscriberDB SYSNAME = 'ReplDB';

DECLARE @MachineName NVARCHAR(128) = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128));
DECLARE @DistLogin   SYSNAME = @MachineName + '\repl_distribution';
DECLARE @DistPassword NVARCHAR(255) = 'Poste@2025';

-- =========================================
-- CREATE PUSH SUBSCRIPTION
-- =========================================
EXEC sp_addsubscription
    @publication = @Publication,
    @subscriber = @Subscriber,
    @destination_db = @SubscriberDB,
    @subscription_type = 'Push',
    @sync_type = 'automatic';

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

    -- Subscriber connection (you used sa)
    @subscriber_security_mode = 0,
    @subscriber_login = 'sa',
    @subscriber_password = 'P@ssw0rd',

    -- Continuous execution
    @frequency_type = 64;
GO
