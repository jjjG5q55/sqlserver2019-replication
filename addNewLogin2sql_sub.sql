USE [master];
GO

-- Replace with your domain or keep as is for local accounts
DECLARE @prefix NVARCHAR(128) = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128));
-- Example for domain: SET @prefix = 'MYDOMAIN';

DECLARE @accounts TABLE (name SYSNAME);

INSERT INTO @accounts (name)
VALUES
('repl_distribution'),
('repl_merge');

DECLARE @login SYSNAME;
DECLARE cur CURSOR FOR SELECT name FROM @accounts;

OPEN cur;
FETCH NEXT FROM cur INTO @login;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @fullLogin NVARCHAR(256) = QUOTENAME(@prefix + '\' + @login);

    IF NOT EXISTS (
        SELECT 1 
        FROM sys.server_principals 
        WHERE name = @prefix + '\' + @login
    )
    BEGIN
        DECLARE @sql NVARCHAR(MAX) =
            'CREATE LOGIN ' + @fullLogin + ' FROM WINDOWS;';
        EXEC(@sql);

        PRINT 'Created login: ' + @prefix + '\' + @login;
    END
    ELSE
    BEGIN
        PRINT 'Login already exists: ' + @prefix + '\' + @login;
    END

    FETCH NEXT FROM cur INTO @login;
END

CLOSE cur;
DEALLOCATE cur;
GO
