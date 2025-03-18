/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Um dos primeiro scripts para fazer backup que eu criei


*/

DECLARE
	@DataAgora datetime
	,@YMD char(8) --> YYYYMMDD
	,@HMS char(6) --> HHMinMinSS
	,@PastaDestino	varchar(500)
	,@Comprimir		bit
	,@Tipo			char(1)
	,@Banco			varchar(200)
	,@Stats			int
	
SET @PastaDestino	= 'C:\temp'
SET @Comprimir		= 1
SET @Tipo			= 'F'
SET @Stats			= 10
	

IF OBJECT_ID('tempdb..#BancosBackup') IS NOT NULL
	DROP TABLE #BancosBackup;
	
SELECT
	D.name
	,ROW_NUMBER() OVER(ORDER BY SUM(MF.size)) as Seq
INTO
	#BancosBackup
FROM
	sys.databases D
	INNER JOIN
	sys.master_files MF
		ON MF.database_id = D.database_id
where
	D.name not in ('tempdb','model')
	AND	D.name not in
	(
SELECT
	bs.DATABASE_NAME
FROM
	msdb.dbo.backupset BS WITH(NOLOCK)
WHERE
	BS.backup_finish_date >= '03/17/2012 22:00'
	)
GROUP BY
	D.name
	
	
--> Variáveis auxiliares
DECLARE
	@NomeBanco varchar(200)
	,@ComandoBackup nvarchar(max)
	,@CaminhoArquivoBkp nvarchar(500)
	,@TipoBackup nvarchar(30)
	,@ExtensaoBackup char(3)
	,@NomeArquivoBkp nvarchar(500)
	,@TimestampIni datetime
	,@TimestampFim datetime
	,@TempoTotalMS int
	
--> Definindo a query para o cursor.
DECLARE
	c_Backups CURSOR FORWARD_ONLY FAST_FORWARD
FOR
	SELECT BB.name FROM #BancosBackup BB ORDER BY BB.seq
;

OPEN c_Backups;
FETCH NEXT FROM c_Backups INTO @NomeBanco;

SET @TipoBackup = CASE @Tipo
						WHEN 'I' THEN 'DIFF'
						WHEN 'L' THEN 'LOG'
						ELSE 'FULL'
					END

SET @ExtensaoBackup = CASE @TipoBackup
						WHEN 'LOG' THEN 'trn'
						ELSE 'bak'
					END

WHILE @@FETCH_STATUS = 0 BEGIN

	--> Determinando as informacoes da data agora.
	SET @DataAgora	= CURRENT_TIMESTAMP;
	SET @YMD		= CONVERT(varchar(8),@DataAgora,112);
	SET @HMS		= REPLACE(CONVERT(varchar(8),@DataAgora,114),':','');


	SET @NomeArquivoBkp = @YMD+'_'+@HMS +'$'+@NomeBanco +'$'+@TipoBackup +'.'+@ExtensaoBackup;
	SET @CaminhoArquivoBkp = @PastaDestino +'\'+@NomeArquivoBkp;

	SET @ComandoBackup = '
BACKUP DATABASE
	'+@NomeBanco+'
TO
	DISK =  '+QUOTENAME(@CaminhoArquivoBkp,'''')+'
WITH
	STATS = '+CONVERT(varchar(3),@Stats)+'
	'+CASE @Comprimir WHEN 1 THEN ',COMPRESSION' ELSE '' END+'
	'

	RAISERROR('--------------------------------------------------------------------',0,0) WITH NOWAIT;
	RAISERROR('Iniciando backup do banco %s',0,0,@NomeBanco) WITH NOWAIT;
	RAISERROR('%s',0,0,@ComandoBackup) WITH NOWAIT;
	
	SET @TimestampInI = CURRENT_TIMESTAMP;
	EXEC(@ComandoBackup)
	SET @TimestampFim = CURRENT_TIMESTAMP;
	SET @TempoTotalMS = DATEDIFF(ms,@TimestampIni,@TimeStampFim)
	
	RAISERROR('Tempo total em milisegundos de backup: %d',0,0,@TempoTotalMS) WITH NOWAIT;
	RAISERROR('--------------------------------------------------------------------',0,0) WITH NOWAIT;

	FETCH NEXT FROM c_Backups INTO @NomeBanco;
END

CLOSE c_Backups;
DEALLOCATE c_Backups;