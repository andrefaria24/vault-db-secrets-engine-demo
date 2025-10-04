-- Create Databases
USE [master]
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'test_db_1')
    CREATE DATABASE test_db_1;

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'test_db_2')
    CREATE DATABASE test_db_2;
GO

-- Create Logins
USE [master]
CREATE LOGIN [vault_login] WITH PASSWORD=N'<YOUR_PASSWORD>', DEFAULT_DATABASE=[master]
ALTER SERVER ROLE [sysadmin] ADD MEMBER [vault_login]
GO

USE [master]
CREATE LOGIN [vault_static] WITH PASSWORD=N'<YOUR_PASSWORD>', DEFAULT_DATABASE=[master]
GO

-- Create Users
USE [test_db_1]
CREATE USER [vault_static] FOR LOGIN [vault_static] WITH DEFAULT_SCHEMA=[dbo]
ALTER ROLE [db_owner] ADD MEMBER [vault_static]
GO