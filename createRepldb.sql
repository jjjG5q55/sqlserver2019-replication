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

--------create schemma 
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'arts')
BEGIN
    EXEC('CREATE SCHEMA [arts]');
    PRINT 'Schema arts created.';
END
ELSE
    PRINT 'Schema arts already exists.';
GO
