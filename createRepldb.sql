-- =========================================
-- Create database if not exists
-- =========================================
IF DB_ID('ReplDB') IS NULL
BEGIN
    CREATE DATABASE ReplDB;
END
GO

-- =========================================
-- Build server-based login names
-- =========================================
DECLARE @DistLogin SYSNAME = @@SERVERNAME + '\repl_distribution';
DECLARE @MergeLogin SYSNAME = @@SERVERNAME + '\repl_merge';

-- =========================================
-- Create database context
-- =========================================
USE ReplDB;
GO

-- =========================================
-- Create database users if missing
-- =========================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @@SERVERNAME + '\repl_distribution')
BEGIN
    EXEC('CREATE USER [' + @@SERVERNAME + '\repl_distribution] 
          FOR LOGIN [' + @@SERVERNAME + '\repl_distribution]');
END

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @@SERVERNAME + '\repl_merge')
BEGIN
    EXEC('CREATE USER [' + @@SERVERNAME + '\repl_merge] 
          FOR LOGIN [' + @@SERVERNAME + '\repl_merge]');
END
GO

-- =========================================
-- Add db_owner role
-- =========================================
ALTER ROLE db_owner ADD MEMBER [$(=@@SERVERNAME)\repl_distribution];
ALTER ROLE db_owner ADD MEMBER [$(=@@SERVERNAME)\repl_merge];
GO
