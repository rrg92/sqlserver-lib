/** 	
	DEMO
		Corrupção no leaf do índice cluster
	Objetivo
		Cluster corrompido, como recuperar!
		considerando que não teria cover index suficiente para remontar os dados!

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

-- Recovery SIMPLE (tanto faz...) (Não vai poder, se tiver usando Snapshot)
	ALTER DATABASE DBCorrupt SET RECOVERY SIMPLE;

-- obtendo 10 paginas aleatorias do indice cluster...
	-- vamos escolher a primeira e corromper ela!
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
	ORDER BY checksum(newid())
	

-- Usando dbcc writepage para simular corrupção!
-- help: dbcc WRITEPAGE ({'dbname' | dbid}, fileid, pageid, offset, 
--							length, data [, directORbufferpool])
	-- Corrompendo páginas leaf
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC WRITEPAGE('DBCorrupt',1,17638,'m_pageId',6,0x000000000000,0)	 -- ajustar num pagina
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;
	checkpoint; dbcc dropcleanbuffers;

	


--> Tabela corrompida?
	declare @eat bigint
	SELECT @eat = checksum(*)
	FROM DBCorrupt.dbo.Lancamentos


 

	--> Criando uma tabela para guardar os os dados...
	CREATE TABLE DBCorrupt.[dbo].[tmpLancamentos](
		DataLancamento date NOT NULL,NumConta int NOT NULL,
		Seq smallint NOT NULL,Tipo char(1) NOT NULL,
		Valor money NOT NULL,Moeda char(3) NOT NULL,
		Origem char(1) NOT NULL
		,HashLancamento uniqueidentifier NOT NULL,
		CONSTRAINT [tmpPK_Lancamento] PRIMARY KEY CLUSTERED 
			([DataLancamento] ASC,[NumConta] ASC,[Seq] ASC)	
	)

	--> Descobrindo o leaf antes e depois
	DBCC TRACEON(3604);
	DBCC PAGE('DBCorrupt',1,17638,2) 	with tableresults -- ajustar num da pagina!

		-- aq assumimos que o campo m_prevPage não foi afetaod pela corrupção...
		-- mas poderia ser!
		--m_prevPage	(1:17637)
		--m_nextPage	(1:17639)

		-- outra maneira seria: iter over todas as paginas e tentaria acessar com 3 para saber o range que foi perdido!

	--> Verificando qual é o ultimo registro (último slot)
		--> Esse é o maior que conseguimos recuperar antes da corrupção!
	DBCC PAGE('DBCorrupt',1,17637,3) WITH TABLERESULTS; 
	
	--> Guardando os registros 
	-- todos os registros ANTERIORES a última data
	-- (A página corrompida pode conter registros 
	-- com esta data)
	INSERT DBCorrupt.dbo.tmpLancamentos
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos
	WHERE DataLancamento < '20151022'  -- 2015-10-22;19969;1

	--> Registros com a data, e anteriores a última conta...
	INSERT DBCorrupt.dbo.tmpLancamentos
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos
	WHERE DataLancamento = '20151022'	-- atualizar filtro
			AND NumConta < 19969

	--> Salvamos o que falta...
	INSERT DBCorrupt.dbo.tmpLancamentos
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos
	WHERE DataLancamento = '20151022'
			AND NumConta = 19969
			AND Seq = 1
		  ---> Obs.: Não sabemos se há o Seq = 2...


	-- o que acontece se tentarmos acessar apos?
	SELECT top 5 *,sys.fn_PhysLocFormatter(%%physloc%%)
	FROM DBCorrupt.dbo.Lancamentos
	WHERE DataLancamento = '20151022'
	and NumConta >= 19969

	
		

--> Salvando após a pagina corrompida...
	
	--> pegar o m_nextPage consultado anteriormente
	--> Buscar o slot 0
	DBCC PAGE('DBCorrupt',1,17639,3) WITH TABLERESULTS

		
		
		

	--> Salvando todos os registros após a maior data.
	-- (Registros iguais podem existir na página corrompida)
	insert into DBCorrupt.dbo.tmpLancamentos
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos
	WHERE DataLancamento > '20151023'	--2015-10-23;10142;1

	


	--> Salvando registros iguais a data
		-- Maiores que a primeira conta
	insert into DBCorrupt.dbo.tmpLancamentos
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos
	WHERE DataLancamento = '20151023'
		AND NumConta > 10142 
		
	--> Salvando registros iguais a primeira conta,
	-- Maiores que o primeiro Seq...
	insert into DBCorrupt.dbo.tmpLancamentos
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos
	WHERE DataLancamento = '20151023'
		AND NumConta = 10142 
		AND Seq >= 1 


-- O que perdeu? (aproximado)
	SELECT	
		DataLancamento
		,NumConta
		,Seq
	FROM DBCorrupt.dbo.Lancamentos
		with(index(Ix_valor)) --> usando um indice alternativo
	WHERE 
		DataLancamento = '20151022' and DataLancamento <= '20151023'
	-- AND NumConta between 19969 and 10142 


	-- Vamos deixar o SQL tentar recuperar...
	-- vai gerar alguns erros com o que conseguiu reparar!
	USE master;
	ALTER DATABASE DBCorrupt SET SINGLE_USER
		WITH ROLLBACK IMMEDIATE
	USE DBCorrupt;
	DBCC CHECKTABLE('Lancamentos'
		,REPAIR_ALLOW_DATA_LOSS )
	ALTER DATABASE DBCorrupt SET MULTI_USER
		WITH ROLLBACK IMMEDIATE


	-- Comparando o que 
	-- recuperamos com o que o SQL recuperou.
	SELECT COUNT(*) FROM DBCorrupt.dbo.tmpLancamentos
	SELECT COUNT(*) FROM DBCorrupt.dbo.Lancamentos

	-- Em caso de diferenças, podemos determinar
	-- o que conseguimos recuperar e o sql não...
	SELECT * FROM DBCorrupt.dbo.tmpLancamentos
	EXCEPT 
	SELECT * FROM DBCorrupt.dbo.Lancamentos
	
	-- E o que o sql conseguiu recuperar e nós não...
	SELECT * FROM DBCorrupt.dbo.Lancamentos
	EXCEPT 
	SELECT * FROM DBCorrupt.dbo.tmpLancamentos


