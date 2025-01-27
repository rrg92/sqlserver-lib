/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Retorna a sequência de RESTORE para um banco!
		Útil para rapidamente montar os comandos de restore!
		Pode te ajudar a ganhar tempo para executar um restore de emergência!
		Informe o banco e o full máximo, e a partir disso, o script descobre os difs e logs para serem usados!

*/
-- Preencha essa tabela com os nomes dos bancos que queria!
-- Deixei uma temp table para facilitar popular com algum script se você precisar!
IF OBJECT_ID('tempdb..#BasesRestore') IS NOT NULL 
	DROP TABLE #BasesRestore;



-->>>> PARÂMETROS DO SCRIPT	
-- Basta popular a tabela #BasesRestore(coluna name) com o nome dos bancos que quer. 1 banco por linha.

	SELECT 'NomeBanco' name INTO #BasesRestore;

	DECLARE 
		@BackupPath nvarchar(max) 	= 'C:\Origem'		--> diretorio onde os backupa estarão
		,@ReplacePath nvarchar(max) = 'C:\Destino' 	--> diretorio original 
		,@MaxFullDate datetime 		= GETDATE()			--> Usar um full com, no máximo, essa data. A partir disso, pegará os logs digs!
														-- Use isso para que o script limite qual full vai usar, permitindo você escolher um full anterior ao mais recente!



---- DAQUI PRA FRENTE NÃO PRECISA MAIS ALTERAR --- 
-- Se a query ficar muito lenta, esse índice me ajudou... 
-- Mas, crie por sua própria conta e risco, visto que não é recomendando mexer em tabelas mantidas pela microsoft!!!!
-- --create index ixtemp on  backupset(database_name,type,is_copy_only) with(data_compression = page)



USE msdb;

SELECT
	 DatabaseName = R.name
	,LastFull = b.backup_finish_date
	,b.FullSizeGB
	,LastDiff = d.backup_finish_date
	,d.DiffSizeGB
	,LastLog.*
	,FullRestoreSql = 'RESTORE DATABASE '+quotename(r.name)+' from disk = '''+b.FullRestorePath+''' WITH NORECOVERY,stats = 10'
	,FullRestoreDiff = 'RESTORE DATABASE '+quotename(r.name)+' from disk = '''+d.DiffRestorePath+''' WITH NORECOVERY,stats = 10'
	,LogsRestore = L.restoreslog
FROM
	#BasesRestore R
	CROSS APPLY (
		select top 1  bs.backup_finish_date,backup_set_id
		,FullRestorePath = REpLACE(f.physical_device_name,@ReplacePath,@BackupPath)
		,FullSizeGB = bs.compressed_backup_size/1024/1024/1024
		From backupset bs
		join backupmediafamily f
			on f.media_set_id = bs.media_set_id
		
		where type = 'D' and database_name = R.name
		and  is_copy_only = 0
		and backup_finish_date < ISNULL(@MaxFullDate,GETDATE())
		order by backup_set_id desc
	) b
	OUTER APPLY (
		select top 1  bs.backup_finish_date,backup_set_id
		,DiffRestorePath = REpLACE(f.physical_device_name,@ReplacePath,@BackupPath)
		,DiffSizeGB = bs.compressed_backup_size/1024/1024/1024
		From backupset bs
		join backupmediafamily f
			on f.media_set_id = bs.media_set_id
		
		where type = 'I' and database_name = R.name
		and backup_finish_date > b.backup_finish_date
		and  is_copy_only = 0
		order by backup_set_id desc
	) d
	outer APPLY (
		select 
			[data()] = 'RESTORE LOG '+quotename(r.name)+' from disk = '''+LogRestorePath+''' WITH NORECOVERY,stats = 10'+CHAR(13)+CHAR(10)
		from (
		select   bs.backup_finish_date
		,LogRestorePath = REpLACE(f.physical_device_name,@ReplacePath,@BackupPath)
		From backupset bs
		join backupmediafamily f
			on f.media_set_id = bs.media_set_id
		
		where type = 'L' and database_name = R.name
		and  is_copy_only = 0
		AND backup_finish_date > isnull(d.backup_finish_date,b.backup_finish_date)
		) rl
		order by backup_finish_date
		FOR XML PATH(''),type
	) l(restoreslog)
	outer APPLY (
		select 
			 FirstLog	= min(bs.backup_finish_date)
			,LastLog	= max(bs.backup_finish_date)
			,TotalLogs = count(*)
			,TotalLogSizeGB = sum(compressed_backup_size/1024/1024/1024)
		From backupset bs
		join backupmediafamily f
			on f.media_set_id = bs.media_set_id
		where type = 'L' and database_name = R.name
		and  is_copy_only = 0
		AND backup_finish_date > isnull(d.backup_finish_date,b.backup_finish_date)
	) LastLog

