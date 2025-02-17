/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		
		Eu acho que essa foi uma das primeiras procs que criei para fazer backup.
		Eu queria ter algo que chegasse fácil em um ambiente e caso nao tivesse backup ja colocava pra rodar.

		Acho que hoje ja existe solucoes muito melhores...
		Mas, ainda sim, por ser um script bem simples, pode ser útil para quebrar um galho por aí.
*/

USE master
GO

IF OBJECT_ID('dbo.sp_DoBackup') IS NULL
	EXEC('CREATE PROCEDURE sp_DoBackup AS SELECT 0 AS StubVersion');
	EXEC sp_MS_marksystemobject sp_DoBackup;
GO

ALTER PROCEDURE sp_DoBackup
(
	@folder nvarchar(1000) = NULL
	,@database nvarchar(1000) = NULL
	,@backupType varchar(50) = 'FULL'
	,@Compression bit = 1
	,@CopyOnly bit = 1
	,@Mode smallint = 1  -- 1 - Print Only | 2 - Execute | 3 - Print and Execute
	,@ReturnFileName bit = 0
)
AS

--DECLARE
--	@folder nvarchar(1000)
--	,@database nvarchar(1000)
--	,@backupType varchar(50)
--	,@Compression bit
--	,@CopyOnly bit
--	,@Mode smallint
	
--SET @folder = '\\10.1.114.30\sql\Import';
--SET @database = 'msdb';
--SET @Mode  = 1;
--SET @Compression = 1;

-------------

-- Validating @Database
IF @database IS NULL
	SET @database = DB_NAME()

-- Validating @folder
	IF @folder IS NULL
		SET @folder = '';

	IF RIGHT(@folder,1) NOT IN ('\','/')
		SET @folder = @folder + '\';

	IF RIGHT(@folder,1) NOT IN ('\','/')
		SET @folder = @folder + '\';

-- Validating @BackupType
	IF @backupType IS NULL
		SET @backupType = 'FULL';

	IF @backupType NOT IN ('FULL','LOG','DIFF')
	BEGIN
		RAISERROR('Invalid backup type: %s',16,1,@backupType);
		return;
	END

DECLARE
	@cmdBackup nvarchar(4000)
	,@serverName nvarchar(200)	
	,@timestamp varchar(20)
	,@finalFilename varchar(600)
	,@tsql_compression varchar(200)
	,@tsql_backupType varchar(20)
	,@tsql_DiffWith nvarchar(100)
	,@tsql_CopyOnly nvarchar(100)
	,@FileExtension varchar(15)
	;

-- Collecting auxiliary informations
SET @serverName = REPLACE(@@SERVERNAME,'\','-');
SET @timestamp = REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(varchar(23),CURRENT_TIMESTAMP,121),'-',''),':',''),' ',''),'.','')

-- Determining features...
IF @Compression = 1
	SELECT @tsql_compression = 'COMPRESSION' FROM msdb.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'backupset' AND COLUMN_NAME = 'compressed_backup_size'
-- Determining features...
IF @CopyOnly = 1
	SELECT @tsql_CopyOnly = 'COPY_ONLY' FROM msdb.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'backupset' AND COLUMN_NAME = 'is_copy_only'

-- Determining extensions
SET @FileExtension = CASE 
						WHEN @backupType = 'LOG' THEN 'trn'
						ELSE 'bak'
					END

-- Determing backup type tsql
SET @tsql_backupType = CASE WHEN @backupType IN ('FULL','DIFF') THEN 'DATABASE' ELSE 'LOG' END;
SET @tsql_DiffWith = CASE WHEN @backupType IN ('DIFF') THEN 'DIFFERENTIAL' ELSE NULL END;
SET @finalFilename = @folder+@serverName+'_'+@database+'_'+@backupType+'_'+@timestamp+'.'+@FileExtension

SET @cmdBackup = '
	BACKUP '+@tsql_backupType+' 
		['+@database+'] 
	TO DISK =  '''+@finalFilename+''' 
	WITH
		STATS = 10
	'+ISNULL(','+@tsql_compression,'')+'
	'+ISNULL(','+@tsql_DiffWith,'')+'
	'+ISNULL(','+@tsql_CopyOnly,'')+'
';

IF @Mode in (1,3)
	PRINT @cmdBackup

IF @Mode in (2,3)
	EXEC(@cmdBackup)

IF @ReturnFileName = 1
	SELECT @finalFilename as backupfile