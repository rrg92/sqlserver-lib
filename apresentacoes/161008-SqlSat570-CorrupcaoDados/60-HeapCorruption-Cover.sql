/** DEMO
		Reconstruíndo a tabela a partir dos "Cover Indexes"
	Objetivo
		Mostrar como recuperar a tabela quando há "Cover Indexes" suficiente!

	Autores:
		Gustavo Maia Aguiar
		Rodrigo Ribeiro Gomes
**/


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

USE DBCorrupt
go

--> Transforma a tabela em HEAP!
	SET XACT_ABORT ON;
	BEGIN TRAN;
		declare @drop nvarchar(max) = (
			SELECT 'ALTER TABLE Lancamentos DROP CONSTRAINT '+quotename(name) FROM sys.key_constraints where 
			parent_object_id = object_id('dbo.Lancamentos')
		)
		exec(@drop);

		alter table Lancamentos
		add constraint PK_LANCAMENTOS primary key nonclustered (DataLancamento,NumConta,Seq) 
	COMMIT;


-- Usando dbcc writepage para simular corrupção!
-- help: dbcc WRITEPAGE ({'dbname' | dbid}, fileid, pageid, offset, length, data [, directORbufferpool])
	-- Corrompendo o várias páginas da heap!
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DECLARE @cmdSQL nvarchar(max) = (
			SELECT TOP(100)
				'DBCC WRITEPAGE(''DBCorrupt'','
				+CONVERT(varchar(10),P.allocated_page_file_id)
				+','+CONVERT(varchar(10),P.allocated_page_page_id)
				+',''m_pageId'',6,0x000000000000,0);'  
			FROM
				DBCorrupt.sys.dm_db_database_page_allocations(
					DB_ID('DBCorrupt')
					,OBJECT_ID('DBCorrupt.dbo.Lancamentos')
					,0
					,NULL
					,'DETAILED'
				) P
			WHERE P.page_type_desc = 'DATA_PAGE'
			ORDER BY CHECKSUM(NEWID())
			FOR XML PATH,type
		).value('.','nvarchar(max)')
		print(@cmdSQL)
		EXEC(@cmdSQL);
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;
	checkpoint; dbcc dropcleanbuffers;
	

--> Tabela corrompida?
declare @eat bigint
SELECT  @eat = checksum(*) FROM DBCorrupt.DBO.Lancamentos

-- Os índices que temos são!
	EXEC DBCorrupt..sp_helpindex 'DBO.Lancamentos'
	SELECT index_id,name,filter_definition 
	FROM DBCorrupt.sys.indexes 
	WHERE object_id = OBJECT_ID('DBCorrupt.dbo.Lancamentos') 

	-- Conseguiremos recuperar estas informações com o 
	-- conjunto de índices! (VER PLANO)
	SELECT 
		L1.DataLancamento
		,L1.NumConta,L1.Seq,L1.Moeda
		,L1.Origem,L1.Valor 
	FROM  
		DBCorrupt.DBO.Lancamentos L1 
		WITH(INDEX(PK_LANCAMENTOS,IX_Moeda,IX_Origem,IX_Valor)) 

		-- O Tipo e o Hash não pode ser recuperado por este método!

			
	-- query para montar o select automatico com o que da!	
	;With Cols as (
		select
			c.name
			,Idx.*
		from
			sys.columns C
			outer apply (
				select 
					IndexName = i.name
				from
					sys.index_columns ic 
					join
					sys.indexes i
						on i.object_id = ic.object_id
						and i.index_id = ic.index_id
				where
					i.object_id = c.object_id
					and ic.column_id = c.column_id
			) Idx
		where
			c.object_id = object_id('dbo.Lancamentos')
	)
	select 
		'select '+stuff(Colunas,1,1,'')
		+' from lancamentos with(index('+stuff(Indices,1,1,'')+'))'
	from (
		select 
			Colunas  = (select distinct ','+name from Cols  where IndexName is not null for xml path('')) 
			,Indices = (select distinct ','+IndexName from Cols  where IndexName is not null for xml path(''))
	) l

	

