/** 	
	DEMO
		Cenários de corrupção
	Objetivo
		Mostrar as várias formas como uma corrupção pode se apresentar

	Autores:
		Gustavo Maia Aguiar
		Rodrigo Ribeiro Gomes
**/



-- Restaurando a base ORIGINAL!!
	USE master 
	GO

	IF OBJECT_ID('tempdb..spRestore') IS NOT NULL
		EXEC('DROP PROC spRestore')
	GO

	CREATE PROC spRestore
	AS
		IF DB_ID('DbCorrupt') IS NOT NULL
		BEGIN
			EXEC('ALTER DATABASE DbCorrupt SET READ_WRITE WITH ROLLBACK IMMEDIATE')
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

		--Base em recovery SIMPLE!
		ALTER DATABASE DBCorrupt SET RECOVERY SIMPLE;  -- Neste cenário o RECOVERY MODEL não interfere... tanto faz... vou deixar no simple, que é o mais restritivo!
	GO

	USE master;
	EXEC spRestore;
	USE DBCorrupt
	GO



-- Checksum em páginas de dados
	ALTER DATABASE DBCorrupt SET PAGE_VERIFY CHECKSUM -- Padrão 2008+

	-- confirmando que tudo ok
	select top 1 
		*
	from
		dbo.Lancamentos
	order by
		DataLancamento

	-- vamos corromper a primeira página!
	SELECT top 10 P.allocated_page_page_id,P.page_level
		,P.previous_page_page_id,P.next_page_page_id
		,p.page_type_desc ,p.extent_page_id
	FROM
		DBCorrupt.sys.dm_db_database_page_allocations(
			DB_ID('DBCorrupt')
			,OBJECT_ID('DBCorrupt.dbo.Lancamentos')
			,1
			,NULL
			,'DETAILED'
		) P
	WHERE P.page_level = 0 and p.page_type_desc = 'DATA_PAGE'
	ORDER BY p.allocated_page_page_id

	-- write page!
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	-- dbcc traceon(2588) dbcc tracestatus	
	-- dbcc help('writepage')
	-- banco,file,pagina,start,length,data,direct
	DBCC WRITEPAGE('DBCorrupt',1,360,0,2,0x1234,1) -- direct = nao calcula checsum
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

	-- vamos ler
	select top 1 
		*
	from
		dbo.Lancamentos
	order by
		DataLancamento

	-- como contornar?
	ALTER DATABASE DBCorrupt SET PAGE_VERIFY none

		-- TENTA NOVAMENTE acima



		-- volta pro checksum
		ALTER DATABASE DBCorrupt SET PAGE_VERIFY checksum

		-- tenta novamente...
	-- deu? agora:  
		checkpoint; dbcc dropcleanbuffers

			-- tenta novamente
			-- checksum só é verificado quando é lida do disco!


-- campos com valores incorretos pageId (Será que checksum resolve?)

	-- restaurar o banco de novo...
	USE master;
	EXEC spRestore;
	USE DBCorrupt
	GO


	-- mostrar o campo m_PageId
	DBCC TRACEON(3604)
	DBCC PAGE('DBCorrupt',1,360,2) with tableresults


	-- m_NextPage = (0:0)
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC WRITEPAGE('DBCorrupt',1,360,'m_pageId',6,0x000000000000,0) -- via bpool, pro checksum ficar ok.
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

	-- alterou?	ParentObject = PAGE HADER  , Field = m_PageId
	DBCC PAGE('DBCorrupt',1,360,2) with tableresults

	-- vamos ler
	-- SE TIVER NORMAL: checkpoint; dbcc dropcleanbuffers
	select top 1 
		*
	from
		dbo.Lancamentos
	order by
		DataLancamento

		
		

		
		-- desligar o page_verify
		-- como contornar?
		ALTER DATABASE DBCorrupt SET PAGE_VERIFY none
			-- resolve?
		
		-- volta
		ALTER DATABASE DBCorrupt SET PAGE_VERIFY checksum



	-- checkdb
	dbcc checkdb(DbCorrupt)
	dbcc checktable(Lancamentos)
	dbcc checkdb(DbCorrupt) with physical_only
	dbcc checktable(Lancamentos)  with physical_only

	

	--  fix
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC CHECKTABLE(Lancamentos,REPAIR_REBUILD)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

	
	
	-- allow data loss
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC CHECKTABLE(Lancamentos,REPAIR_allow_data_loss)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

	-- vamos ler (perdeu algo??)
	select top 1 
		*
	from
		dbo.Lancamentos
	order by
		DataLancamento

-- header zerado! (Será que checksum resolve?)
	
	-- restaurar o banco de novo...
	USE master;
	EXEC spRestore;
	USE DBCorrupt
	GO

	DBCC TRACEON(3604)
	DBCC PAGE('DBCorrupt',1,360,2) with tableresults

	-- vamos corromper o header!
	declare @sql nvarchar(max)
	declare @bin varchar(max) = convert(varchar(max),convert(varbinary(96),replicate(0x00,96)),1)
	set @sql = 'DBCC WRITEPAGE(''DBCorrupt'',1,360,0,96,'+@bin+',0)'
	print(@sql)
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	exec(@sql)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

	-- tabela voltou? repare o id!
	select top 1 * from Lancamentos

		-- resolve?
		ALTER DATABASE DBCorrupt SET PAGE_VERIFY none
		-- volta
		ALTER DATABASE DBCorrupt SET PAGE_VERIFY checksum

	-- allow data loss
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC CHECKTABLE(Lancamentos,REPAIR_allow_data_loss)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

			
-- campos com valores incorretos (next page) (PODE SER BEM DIFÍCIL DETECTAR E RESOLVER ESSA)

	-- restaurar o banco de novo...
	USE master;
	EXEC spRestore;
	USE DBCorrupt
	GO


	DBCC TRACEON(3604)
	DBCC PAGE('DBCorrupt',1,360,0) with tableresults


	-- m_NextPage = (0:0)
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC WRITEPAGE('DBCorrupt',1,360,'m_nextPage',6,0x000000000000,2) -- via bpool, pro checksum ficar ok.
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

	

	 -- quantas linhas tem?
	select count(*) from dbo.Lancamentos

	-- será mesmo?
	select * from Lancamentos


	--
	select count(*) from Lancamentos with(index(0))

	select count(*) from lancamentos with(index(0)) option(maxdop 1)


	-- como pega? (por isso importancia disso rodar periodicamente)
	DBCC CHECKDB('DbCorrupt')
	DBCC CHECKTABLE(Lancamentos)
	DBCC CHECKTABLE(Lancamentos) with physical_only -- ops
	DBCC CHECKDB('DbCorrupt') with physical_only -- ops


	-- repair funciona?
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC CHECKTABLE(Lancamentos,REPAIR_REBUILD)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

		-- repetir os count após isso...

-- campos com valores incorretos (pagina ida e volta) (MAIS DIFICIL DE ACONTECER)

	-- restaurar o banco de novo...
	USE master;
	EXEC spRestore;
	USE DBCorrupt
	GO

	-- pegar as 2 primeiras (linkadas uma com a outra)
	SELECT top 5 P.allocated_page_page_id,P.previous_page_page_id,P.page_level
		,P.previous_page_page_id,P.next_page_page_id
		,p.page_type_desc ,p.extent_page_id
	FROM
		DBCorrupt.sys.dm_db_database_page_allocations(
			DB_ID('DBCorrupt')
			,OBJECT_ID('DBCorrupt.dbo.Lancamentos')
			,1
			,NULL
			,'DETAILED'
		) P
	WHERE P.page_level = 0 and p.page_type_desc = 'DATA_PAGE'
	ORDER BY p.allocated_page_page_id

	-- vamos zerar o NextPage  e o PrevPage da proxima! Em tese, isso não gera incosistencias.
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC WRITEPAGE('DBCorrupt',1,360,'m_nextPage',6,0x000000000000,2) -- via bpool, pro checksum ficar ok.
	DBCC WRITEPAGE('DBCorrupt',1,376,'m_prevPage',6,0x000000000000,2) -- via bpool, pro checksum ficar ok
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;


	-- primeira pagina
	select *,sys.fn_PhysLocFormatter(%%physloc%%) from Lancamentos
	select count(*) from Lancamentos with(index(0)) option(maxdop 1)

	-- quem estava na segunda (ver ultimo slot)?
	DBCC PAGE('DBCorrupt',1,376,3) with tableresults
	
	-- segunda pagina
	select *
	,sys.fn_PhysLocFormatter(%%physloc%%) 
	from Lancamentos where DataLancamento <= '20150101' and NumConta <= 10341
	order by DataLancamento desc, NumConta DESC



	-- checktable vai pegar?
	DBCC CHECKTABLE(Lancamentos)

	-- e se tentar estragar mais ainda?
		DBCC PAGE('DBCorrupt',1,368,3) 
		-- offset 2
		DBCC PAGE('DBCorrupt',1,368,2) with tableresults
		

		-- vamos tentar zerar...
		ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DBCC WRITEPAGE('DBCorrupt',1,368,8188,2,0x0000,2) -- via bpool, pro checksum ficar ok.
		ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;


		

		-- xi...
		-- agora ficou bem ruim rsrs
		DBCC CHECKTABLE(Lancamentos)

		-- repair funciona?
		ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DBCC CHECKTABLE(Lancamentos, repair_rebuild)
		ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

		-- repair funciona?
		ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DBCC CHECKTABLE(Lancamentos, repair_allow_data_loss)
		ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;

		select top 500 * from Lancamentos

		-- nao vamos continuar, pq ai fica bem compelxo e acho ser bem mais dificil acontecer esse cenario.

	


	