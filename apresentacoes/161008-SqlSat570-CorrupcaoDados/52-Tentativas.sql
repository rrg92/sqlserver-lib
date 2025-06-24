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

	USE DBCorrupt
	GO

-- corrompe o cluster
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

-- Verificar inconsistências
	DBCC CHECKTABLE('Lancamentos') 
	WITH NO_INFOMSGS

-- SELECT com NOLOCK
	declare @eat bigint
	SELECT @eat = checksum(*) 
	FROM Lancamentos WITH (NOLOCK)

-- Rebuild
	ALTER TABLE Lancamentos REBUILD

-- Rebuild Offline
	ALTER TABLE Lancamentos 
	REBUILD WITH (ONLINE=OFF)

-- Reorganize
	ALTER INDEX PK_Lancamento 
	ON Lancamentos REORGANIZE

-- Índice Offline
	select * from sys.key_constraints where parent_object_id = object_id('dbo.Lancamentos')
	ALTER INDEX PK__Lancamen__95B221E9B93E9042 
	ON Lancamentos DISABLE

	-- Tenta consultar
	SELECT * FROM Lancamentos

	-- Índice Online
	ALTER INDEX PK__Lancamen__95B221E9B93E9042 
	ON  Lancamentos REBUILD

-- Corrige os problemas
	ALTER DATABASE DBCorrupt 
	SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DBCC CHECKTABLE('Lancamentos', REPAIR_ALLOW_DATA_LOSS )
	 WITH NO_INFOMSGS
	ALTER DATABASE DBCorrupt
	 SET MULTI_USER WITH ROLLBACK IMMEDIATE

	ALTER INDEX PK__Lancamen__95B221E9B93E9042 ON Lancamentos
	REBUILD


-- naao!
	declare @eat bigint
	SELECT @eat = checksum(*) 
	FROM Lancamentos WITH (NOLOCK)









-- em suma:
	-- nenhuma das tentativas acima deu certo!