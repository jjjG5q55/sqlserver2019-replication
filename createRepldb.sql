-- =========================================
-- Create database if not exists
-- =========================================
IF DB_ID('ReplDB') IS NULL
BEGIN
    CREATE DATABASE ReplDB;
END
GO

USE ReplDB;
GO

DECLARE @MachineName NVARCHAR(128) = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128));
DECLARE @DistLogin   SYSNAME = @MachineName + '\repl_distribution';
DECLARE @MergeLogin  SYSNAME = @MachineName + '\repl_merge';

-- =========================================
-- Create users if missing
-- =========================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @DistLogin)
BEGIN
    EXEC('CREATE USER [' + @DistLogin + '] FOR LOGIN [' + @DistLogin + ']');
END

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @MergeLogin)
BEGIN
    EXEC('CREATE USER [' + @MergeLogin + '] FOR LOGIN [' + @MergeLogin + ']');
END

-- =========================================
-- Add db_owner role
-- =========================================
EXEC('ALTER ROLE db_owner ADD MEMBER [' + @DistLogin + ']');
EXEC('ALTER ROLE db_owner ADD MEMBER [' + @MergeLogin + ']');
GO
