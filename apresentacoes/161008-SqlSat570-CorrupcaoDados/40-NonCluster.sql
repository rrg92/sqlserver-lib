/** 	
	DEMO
		Índice não cluster corrompido!
	Objetivo
		Mostrar como é possível se recuperar de corrupção do índice não cluster!

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


-- Vamos simular uma corrupção em um índice não cluster!


	--Exibindo as páginas do índice IX_Valor
	-- pega a ultima pagina com valor < 150 para corromper (a primeira do resultado provavelmente)
	-- copiar segunda coluna e colar abaixo
	select top 1 with ties	
		Valor
		,sys.fn_PhysLocFormatter(%%physloc%%) -- file:page:slot
	from
		dbo.Lancamentos with(index(ix_valor))
	where
		Valor < 150
	order by
		Valor desc 

		-- pagina:
		-- (1:32338:343)



	--Vamos corromper a página
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;				
	-- lembrar de ajustar o numero da pagina aqui!
	DBCC WRITEPAGE('DBCorrupt',1,32338,'m_pageId',6,0x000000000000,0) 
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;
	checkpoint; dbcc dropcleanbuffers;

	--> Vamos tentar acessar a pagina corropmida!
	SELECT AVG(Valor) 
	FROM DBCorrupt.dbo.Lancamentos 
	WHERE Valor < 150
	
	--> Se um outro índice for usado, 
	-- não há problemas! (VEJA O PLANO DE EXECUÇÃO)
		SELECT Moeda,COUNT(*) 
		FROM DBCorrupt.dbo.Lancamentos 
		GROUP BY Moeda

	--> Se você não tocar na parte corrompida do índice 
	-- também não há problemas!
		SELECT AVG(Valor) 
		FROM DBCorrupt.dbo.Lancamentos 
		WHERE Valor > 150 


	--> Você pode forçar o uso de um outro índice (MOSTRAR PLANO)
		-- para obter seus dados, se você precisar 
		-- dos dados com urgência.
		-- Porém, dependendo do índice, 
		-- você pode ter problemas de perfomance da query.
		SELECT AVG(Valor) FROM 
		DBCorrupt.dbo.Lancamentos WITH(INDEX(1)) 
		WHERE Valor < 150

	--> De qualquer maneira, você 
	-- pode RESOLVER A CORRUPÇÃO do índice não cluster, 
	-- apenas recriando-o:

		-- Você pode tentar fazer um REBUILD OFFLINE
		ALTER INDEX IX_Valor ON 
		DBCorrupt.dbo.Lancamentos
		REBUILD WITH(ONLINE = OFF)

		-- Se falhar o anteior, (devido ao fato 
		-- de que o SQL pode querer usar o velho 
		-- índice pra fazer o REBUILD)
		DROP INDEX IX_Valor 
		ON DBCorrupt.dbo.Lancamentos;
		CREATE INDEX IX_Valor 
			ON DBCorrupt.dbo.Lancamentos(Valor);

	--> E você poderá usar normalmente!
	SELECT AVG(Valor) 
	FROM DBCorrupt.dbo.Lancamentos 
	WHERE Valor < 150