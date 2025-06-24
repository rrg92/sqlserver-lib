/** 	
	DEMO
		Recuperar os dados quando o non leaf está corrompido.
	Objetivo
		mostrar como conseguir acessar os dados sem parar o banco quando o índice não cluster está corrompido no non-leaf  que  não seja primeira ou última

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

	USE DBCorrupt
	GO

	--Base em recovery SIMPLE!
	ALTER DATABASE DBCorrupt SET RECOVERY SIMPLE;  -- Neste cenário o RECOVERY MODEL não interfere... tanto faz... vou deixar no simple, que é o mais restritivo!


--	pegar primeira e segunda pagina non-leaf 
	-- corromper a segunda
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

	-- paginas escolhidas:
	-- 368
	-- 889

-- identificar os valores para usar nos filtros abaixo

	-- primeira non-leaf pega null e 20150101
	-- agora identificar a segunda 
	--DBCC TRACEOFF(3604)
	DBCC PAGE('DBCorrupt',1,889,3)  -- ver inicio, colunas com (key) no nome: 2015-01-04	14742	1
		
	


	
	


-- SIMULAR CORRUPÇÃO NA SEGUNDA PÁGINA!
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC WRITEPAGE('DBCorrupt',1,889,'m_pageId',6,0x000000000000,0) --> Corromper a segunda página (query acima)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;
	checkpoint; dbcc dropcleanbuffers;


	--> Tentando acessar os registros da primeira página... (non-leaf)
	-- > Isso força acessar o non-leaf pra fazer o seek
	SELECT
		*
	FROM
		DBCorrupt.dbo.Lancamentos L
	WHERE
		L.DataLancamento = '20150101'
		AND
		L.NumConta between 10000 and 70000
	
	--> Aqui forçamos um seek começar pela segunda, ja que o filtro nao existe na primeira.
	 -- (olhar o plano estimado)
	SELECT
		*
	FROM
		DBCorrupt.dbo.Lancamentos L
	WHERE
		L.DataLancamento = '20150105'
		AND
		L.NumConta between 10000 and 70001




	
	-- primeira tentativa: forçar um scan!
	SELECT
		*
	FROM
		DBCorrupt.dbo.Lancamentos L WITH(FORCESCAN)
	WHERE
		L.DataLancamento = '20150105'
		AND
		L.NumConta between 10000 and 70001
		-- Por quê????????????????????????????????????
			-- (analisar plano de execução estimado)






		
		
	
	-- paralelismo?
	SELECT
		*
	FROM
		DBCorrupt.dbo.Lancamentos L WITH(FORCESCAN)
	WHERE
		L.DataLancamento = '20150105'
		AND
		L.NumConta between 10000 and 70001
	OPTION(MAXDOP 1)

		-- Por quê????????????????????????????????????









	-- read-ahead está lendo as páginas!!!!
	-- Desabilitando...
	DBCC TRACEON(652);
	DBCC TRACESTATUS(652)

	--> Executando de novo, agora sem o read-ahead
	SELECT 
		*
	FROM
		DBCorrupt.dbo.Lancamentos L WITH(FORCESCAN)
	WHERE
		L.DataLancamento = '20150105'
		AND
		L.NumConta between 10000 and 70001
	OPTION(MAXDOP 1)

	-- para confirmar:
		DBCC TRACEOFF(652);

	--> Recuperar usando DROP INDEX? funciona?
		select * From sys.key_constraints where parent_object_id = object_id('dbo.Lancamentos')
		ALTER TABLE DBCorrupt.dbo.Lancamentos
			DROP CONSTRAINT PK__Lancamen__95B221E9B93E9042





	-- nops!

	DBCC TRACEON(652);DBCC TRACESTATUS(652)
	--> Você pode salvar sua tabela!!
	SELECT 
		*
	INTO
		DBCorrupt.dbo.backupLancamentos
	FROM
		DBCorrupt.dbo.Lancamentos L WITH(FORCESCAN)
	OPTION(MAXDOP 1)
	DBCC TRACEOFF(652);

	--> E se você tiver janela...
	USE DBCorrupt
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	USE DBCorrupt
	DBCC CHECKTABLE('dbo.Lancamentos',REPAIR_ALLOW_DATA_LOSS)
	ALTER DATABASE DBCorrupt SET MULTI_USER;

	--> Houveram perdas?
	SELECT COUNT(*)
	FROM DBCorrupt.dbo.Lancamentos L

	SELECT COUNT(*)
	FROM DBCorrupt.dbo.backupLancamentos
	

	


