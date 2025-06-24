-- Restaurando a base ORIGINAL!!
	USE master 
	GO
	IF DB_ID('DbCorrupt') IS NOT NULL
	BEGIN
		EXEC('ALTER DATABASE DbCorrupt SET READ_ONLY WITH ROLLBACK IMMEDIATE')
		EXEC('DROP DATABASE DbCorrupt')
	END

	RESTORE DATABASE DBCorrupt
	FROM DISK = 'T:\DbCorrupt.bak'
	WITH
		REPLACE
		,STATS = 10
		--,MOVE 'DBCorrupt' TO 'C:\temp\DBCorrupt.mdf'
		--,MOVE 'DBCorrupt_log' TO 'C:\temp\DBCorrupt.ldf'

-- Backup de LOG funciona somente em Recovery FULL ou  BULK LOGGED
	ALTER DATABASE DBCorrupt SET RECOVERY SIMPLE;

-- Corropme algumas pagina aleatoriamente!
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DECLARE @cmdSQL nvarchar(max) = (
			SELECT TOP(100)
				'DBCC WRITEPAGE(''DBCorrupt'','
				+CONVERT(varchar(10),P.allocated_page_file_id)
				+','+CONVERT(varchar(10),P.allocated_page_page_id)
				+',0,2,0x1234,1);'  
			FROM
				DBCorrupt.sys.dm_db_database_page_allocations(
					DB_ID('DBCorrupt')
					,OBJECT_ID('DBCorrupt.dbo.Lancamentos')
					,1
					,NULL
					,'DETAILED'
				) P
			WHERE P.page_type = 1
			ORDER BY CHECKSUM(NEWID())
			FOR XML PATH,type
		).value('.','nvarchar(max)')
		print(@cmdSQL)
		EXEC(@cmdSQL);
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

-- Procedimentos
-- Backup normal funciona?
	BACKUP DATABASE DBCorrupt 
	TO DISK = 'T:\DBCorruptFULL03.BAK' 
	WITH INIT,FORMAT,COMPRESSION,STATS = 10

-- checksum?
	BACKUP DATABASE DBCorrupt 
	TO DISK = 'T:\DBCorruptFULL03.BAK' 
	WITH INIT,FORMAT,COMPRESSION,STATS = 10,checksum

-- Faz um backup da base forçando erros
	BACKUP DATABASE DBCorrupt 
	TO DISK = 'T:\DBCorruptFULL03.BAK'
	WITH 
	COMPRESSION,CHECKSUM, 
	STATS = 10, CONTINUE_AFTER_ERROR

-- Cria um SNAPSHOT da base
	CREATE DATABASE [DBCorrupt_SS]
	ON  PRIMARY (NAME = N'DBCorrupt'
	,FILENAME = N'T:\DBCorrupt_SS.SS')
	AS SNAPSHOT OF DBCorrupt

