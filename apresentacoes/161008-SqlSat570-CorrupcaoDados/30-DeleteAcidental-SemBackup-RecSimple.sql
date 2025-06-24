/** 	
	DEMO
		DELETE SEM WHERE, SEM BACKUP, 
		RECOVERY SIMPLE, ANTES DO CHECKPOINT
	Objetivo
		Mostrar como é possível recuperar dados em uma situação extremamente emergencial.

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
	ALTER DATABASE DBCorrupt SET RECOVERY SIMPLE;

	
	

--E então, um DELETE acidental!!! 
-- (REPARE O NÚMERO DE REGISTROS DELETADOS)
	DELETE TOP(1000)
	FROM DBCorrupt.dbo.Lancamentos
	OUTPUT deleted.* 
	WHERE NumConta = 14324

--> Copia a porção ativa do log imediatamente
	USE DBCorrupt
	IF OBJECT_ID('LogDBCorruptBkp') 
		IS NOT NULL DROP TABLE  dbo.LogDBCorruptBkp
	SELECT * INTO dbo.LogDBCorruptBkp 
	FROM DBCorrupt.sys.fn_dblog(NULL,NULL)

--> Os registros que foram deletados estão no log! 
-- (REPARE O NÚMERO DE REGISTROS RECUPERADO)
	SELECT * 
	FROM dbo.LogDBCorruptBkp 
	WHERE AllocUnitName like 'dbo.Lancamentos.PK_%' 
	AND Operation = 'LOP_DELETE_ROWS'
	-- O número é igual ao do DELETE?
	-- Um para cada linha...



--> Os dados do registro 
-- estão na coluna [RowLog Contents 0]...
	SELECT [RowLog Contents 0] 
	FROM dbo.LogDBCorruptBkp 
	WHERE AllocUnitName like 'dbo.Lancamentos.PK_%' 
	AND Operation = 'LOP_DELETE_ROWS'

--> É possível converter os dados de volta usando, 
-- tratando os registros...
	-- http://www.sqlskills.com/blogs/paul/inside-the-storage-engine-anatomy-of-a-record/
	-- Formato básico da linha: 
	--	Header(4bytes) + DadosTamanhoFixo
	--		Logo, a primeira coluna começa no 
	--		byte de número 5.

--A estrutura da tabela é o seguinte
	EXEC DBCorrupt..sp_help 'dbo.Lancamentos'

--> Aqui vamos recuperar cada coluna!
	IF OBJECT_ID('tempdb..#DadosBinarios') IS NOT NULL
		DROP TABLE #DadosBinarios;
	SELECT 
		[RowLog Contents 0] as					RowContent
		,SUBSTRING([RowLog Contents 0],5,3)		DataLancamento
		,SUBSTRING([RowLog Contents 0],8,4)		NumConta
		,SUBSTRING([RowLog Contents 0],12,2)	Seq
		,SUBSTRING([RowLog Contents 0],14,1)	Tipo
		,SUBSTRING([RowLog Contents 0],15,8)	Valor
		,SUBSTRING([RowLog Contents 0],23,3)	Moeda
		,SUBSTRING([RowLog Contents 0],26,1)	Origem
		,SUBSTRING([RowLog Contents 0],27,16)	HashLancamento
	INTO #DadosBinarios
	FROM dbo.LogDBCorruptBkp 
	WHERE AllocUnitName like 'dbo.Lancamentos.PK_%' 
		AND Operation = 'LOP_DELETE_ROWS'

	SELECT * FROM #DadosBinarios


--> Ótimo, neste ponto já temos os binários, 
-- agora precisamos convert de volta para o tipo de dados!
	SELECT 
		 CONVERT(date,CONVERT(binary(3),DataLancamento))		as DataLancamento
		,CONVERT(int,CONVERT(binary(4),REVERSE(NumConta)))	as NumConta
		,CONVERT(smallint,CONVERT(binary(2),REVERSE(Seq)))		as Seq
		,CONVERT(char(1),Tipo)									as Tipo
		,CONVERT(money,CONVERT(binary(8),REVERSE(Valor)))		as Valor
		,CONVERT(char(3),Moeda)									as Moeda
		,CONVERT(char(1),Origem)								as Origem
		,CONVERT(uniqueidentifier,HashLancamento)				as HashLancamento
	FROM
		#DadosBinarios

--> Coloca os dados lá de volta!
	INSERT INTO dbo.Lancamentos
	SELECT
		 CONVERT(date,CONVERT(binary(3),DataLancamento))		as DataLancamento
		,CONVERT(int,CONVERT(binary(4),REVERSE(NumConta)))	as NumConta
		,CONVERT(smallint,CONVERT(binary(2),REVERSE(Seq)))		as Seq
		,CONVERT(char(1),Tipo)									as Tipo
		,CONVERT(money,CONVERT(binary(8),REVERSE(Valor)))		as Valor
		,CONVERT(char(3),Moeda)									as Moeda
		,CONVERT(char(1),Origem)								as Origem
		,CONVERT(uniqueidentifier,HashLancamento)				as HashLancamento
	FROM
		#DadosBinarios

-- Truncando a porção ativa do log...
	CHECKPOINT;

-- O que acontece se o CHECKPOINT rodar?
	DELETE TOP(1000) FROM DBCorrupt.dbo.Lancamentos 
	WHERE NumConta = 14324

	SELECT COUNT(*)
	FROM DBCorrupt.sys.fn_dblog(NULL,NULL) 
	WHERE AllocUnitName like 'dbo.Lancamentos.PK_%' 
	AND Operation = 'LOP_DELETE_ROWS'

	

	-- rode o checkpoint agora!
	
	CHECKPOINT;

	-- GARANTIR DESLIGADO: DBCC TRACEOFF(2537); DBCC TRACESTATUS
		SELECT COUNT(*)
		FROM DBCorrupt.sys.fn_dblog(NULL,NULL) 
		WHERE AllocUnitName like 'dbo.Lancamentos.PK_%' 
		AND Operation = 'LOP_DELETE_ROWS'

	-- Tracelfag 2537 ?
		-- Inactive portion of log!
		-- http://www.sqlskills.com/blogs/paul/finding-out-who-dropped-a-table-using-the-transaction-log/
	DBCC TRACEON(2537)
	

	-- tenta de novo o select acima!

	

		-- obs: por não ser documentado, pode não funcionar sempre... Tem muita peculiriadedade nessa tf que ainda não consegui mapear!
		-- um dos casos de não funcionr, é a quantidade de VLFs... 
		-- Esse script gera X vlfs (controlarno top X). com 50 ja consegui simular no 2025!
		/*
			-- Pode restaurar novamente e ajustar , ou ajustar o só repetir o teste mudando o filtro do delete.
			-- gera um numero considerável de VLFs...
			declare @sql nvarchar(max) = (
			select
				string_agg(convert(varchar(max),'alter  database	DBCorrupt modify file (name = ''dbcorrupt_log'', size = '+convert(varchar(100),n*50)+'MB)'),';')
			from (
				select top 50
					n  = row_number() over(order by (select null))
				from
					dbo.Lancamentos 
			) t
			)
			dbcc shrinkfile(2,1)
			exec(@sql)

			select * from  sys.dm_db_log_info(db_id('DbCorrupt'))
		*/
	



-- Um cara chamado Muhammad Imran fez 
-- uma proc incrível que faz 
-- todo este procedimento automaticamente!
-- O link para o artigo é:
--  https://raresql.com/2011/10/22/how-to-recover-deleted-data-from-sql-sever/
