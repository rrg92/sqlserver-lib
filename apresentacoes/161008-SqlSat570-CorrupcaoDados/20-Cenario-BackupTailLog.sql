/** 
	DEMO
		Tail do T-LOG
	Objetivo
		Mostrar como o Tail do T-log pode auxiliar na recuperação de dados!

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
	ALTER DATABASE DBCorrupt SET RECOVERY FULL;

-- Vamos criar um BACKUP (SEMPRE FAÇA BACKUP)
	BACKUP DATABASE DBCorrupt 
	TO DISK = 'T:\DBCorrupt_FULL.bak' 
	WITH INIT,FORMAT, STATS=10;

-- Simulando transações na base...
	UPDATE DBCorrupt.DBO.Lancamentos 
	SET Valor = 133.90 
	OUTPUT inserted.DataLancamento
			,inserted.NumConta
			,inserted.Seq,inserted.Valor
			,deleted.Valor as ValorAntigo
	WHERE DataLancamento = '20150101' 
		AND NumConta=9999 AND Seq=1

-- CORROMPER ARQUIVO INTEIRO
--	Abrir o cmd como administrador e rodar p resultado disso:
	declare @ServiceName varchar(500) = isnull('mssql$'+SUBSTRING(@@SERVERNAME,NULLIF(CHARINDEX('\',@@SERVERNAME),0)+1,99),'mssqlserver')
	select 'net stop "'+@ServiceName+'"'
	union all select 'del "'+physical_name+'"' from DBCorrupt.sys.database_files where physical_name like '%.mdf' 
	union all select 'net start "'+@ServiceName+'"'
	union all select ''
	


-- Tenta acessar a base...
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos L
	WHERE DataLancamento = '20150101' 
		AND NumConta=9999 AND Seq=1

--> Vamos fazer o backup do log normal...
	BACKUP LOG DBCorrupt 
	TO DISK = 'T:\DBCorrupt_LOG_1.trn' 
	WITH STATS=10,INIT,FORMAT;
	GO

	-- nao deu? sim nao era pra funcionar mesmo...	👇👇👇👇


--> Faça o backup do T-LOG imediatamente!!!
	BACKUP LOG DBCorrupt 
	TO DISK = 'T:\DBCorrupt_LOG_1.trn' 
	WITH STATS=10,INIT,FORMAT
		,NO_TRUNCATE
		--,NORECOVERY; 
	GO

	



-- Restaurando o FULL...
	RESTORE DATABASE DBCorrupt 
	FROM DISK = 'T:\DBCorrupt_FULL.bak' 
	WITH STATS=10
	, STANDBY = 'T:\DBCorrupt.sby';

-- Verificando o valor atual do registro...
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos L
	WHERE DataLancamento = '20150101' 
		AND NumConta=9999 AND Seq=1

-- Restaura o tail...
	RESTORE LOG DBCorrupt 
	FROM DISK = 'T:\DBCorrupt_LOG_1.trn' 
	WITH STATS=10, RECOVERY

-- Verificando ápós o restore do log...
	SELECT *
	FROM DBCorrupt.dbo.Lancamentos L
	WHERE DataLancamento = '20150101' 
		AND NumConta=9999 AND Seq=1