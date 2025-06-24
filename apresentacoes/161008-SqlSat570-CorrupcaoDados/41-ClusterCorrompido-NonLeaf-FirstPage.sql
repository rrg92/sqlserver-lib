/** 
	DEMO
		Reconstruíndo a tabela a partir dos "Cover Indexes"
	Objetivo
		mostrar como conseguir acessar os dados sem parar o banco quando o índice não cluster está corrompido no non-leaf  que   seja primeira ou última

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
	GO 

	USE DBCorrupt
	GO

	-- checa se existe algujm tf
	dbcc tracestatus -- dbcc traceoff(625)

	--Base em recovery SIMPLE!
	ALTER DATABASE DBCorrupt SET RECOVERY SIMPLE;  -- Neste cenário o RECOVERY MODEL não interfere... tanto faz... vou deixar no simple, que é o mais restritivo!

--	pegar primeira e segunda pagina non-lead 
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
	WHERE P.page_level = 1
	ORDER BY allocated_page_page_id

-- agora, corrompe a primeira
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC WRITEPAGE('DBCorrupt',1,368,'m_pageId',6,0x000000000000,0) --> Corromper a segunda página (query acima)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;
	checkpoint; dbcc dropcleanbuffers;

	--> Tentando acessar o registro...
	SELECT 
		*
	FROM
		DBCorrupt.dbo.Lancamentos L
	WHERE
		L.DataLancamento = '20150101'
		AND
		L.NumConta between 11000 and 19000
	option(maxdop 1)


	-- e se for por trás (lá ele...), lendo tudo?
	-- vamos colocar a variavel para evitar trazer tudo pro client
	DECLARE @eat bigint 
	SELECT 
		@eat = checksum(*) -- checksum força a query ler todas as colunas, e var evita jogar pro client.
	FROM
		DBCorrupt.dbo.Lancamentos L
	ORDER BY
		 L.DataLancamento desc
	option(maxdop 1, recompile)



	--> READ AHEAD?
	DBCC TRACEON(652); -- dbcc tracestatus; dbcc traceoff(652)
	DECLARE @eat bigint 
	SELECT 
		@eat = checksum(*)
	FROM
		DBCorrupt.dbo.Lancamentos L
	ORDER BY
		 L.DataLancamento desc
	option(maxdop 1)

	


	-- ler tudo deu certo, vamos tentar voltar com o filtro
	-- como é menos dados, vamos tirar a variavel!
	-- Agora vamos tentar com os filtros
	-- dbcc tracestatus
	-- (VER PLANO ESTIMADO PARA VER O QUE MUDOU!)
	SELECT 
		*
	FROM
		DBCorrupt.dbo.Lancamentos L	
	WHERE
		L.DataLancamento = '20150101'
		AND
		L.NumConta between 11000 and 19000
	ORDER BY
		 L.DataLancamento desc
	option(maxdop 1, recompile)

		




	-- tentou seek, precisamod forçar um scan!
	dbcc traceon(652) -- dbcc tracestatus	
	SELECT 
		*
	FROM
		DBCorrupt.dbo.Lancamentos L	with(forcescan)
	WHERE
		L.DataLancamento = '20150101'
		AND
		L.NumConta between 11000 and 19000
	ORDER BY
		 L.DataLancamento desc
	option(maxdop 1, recompile)


		-- VER PLANO... ORDERED = TRUE?



	 -- Vamos tentar ordenar pro todos as col do indice!
	 -- DBCorrupt..sp_help Lancamentos
	dbcc traceon(652) -- dbcc tracestatus	
	SELECT 
		*
	FROM
		DBCorrupt.dbo.Lancamentos L	with(forcescan)
	WHERE
		L.DataLancamento = '20150101'
		AND
		L.NumConta between 11000 and 19000
	ORDER BY
		 L.DataLancamento desc, L.NumConta DESC, L.Seq DESC
	option(maxdop 1, recompile)


		-- ver plano, o que mudou?

