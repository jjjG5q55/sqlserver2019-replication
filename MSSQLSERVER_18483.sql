-- Use the Master database
USE master
GO

-- Declare local variables
DECLARE @serverproperty_servername varchar(100),
@servername varchar(100);

-- Get the value returned by the SERVERPROPERTY system function
SELECT @serverproperty_servername = CONVERT(varchar(100), SERVERPROPERTY('ServerName'));

-- Get the value returned by @@SERVERNAME global variable
SELECT @servername = CONVERT(varchar(100), @@SERVERNAME);

-- Drop the server with incorrect name
EXEC sp_dropserver @server=@servername;

-- Add the correct server as a local server
EXEC sp_addserver @server=@serverproperty_servername, @local='local';
