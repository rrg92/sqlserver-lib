/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Durante muito tempo eu senti falta de um script que me desse uma visão dos backups da instância.
		Cansei de ver clientes me perguntarem: Quanto de backup faz por dia, por mês, por ano, etc.  
		Este script foi uma tentativa de conseguir responder isso mais rápido!
		
		Eu fiz ele em inglês, pois na época estava estudando muito inglês e queria forçar tentatr escrever (até hoje faço isso).  
		Por isso, vai ver muito o inglês errado!
		
		Mas o script é bem legal!
		Você ajusta alguns parâmetros e consegue ter uma visão muito legal dos seus backups.
		Ele usa basicamnete a tabela do msdb..backupset. 
		Se ela tiver muito grande, o script pode demorar um pouco. Importante monitorar a execução.
		
		
		eu ajustei a doc dos parâmetros para ficar em português para que você consiga usar!
		
		
		

*/

-- Created  by Rodrigo Ribeiro Gomes (www.thesqltimes.com)
DECLARE
	@RefDate		datetime
	,@period		varchar(10)
	,@GroupByDB		bit
	,@groupPeriod	bit
	,@reporttype	int
	,@considerCopyOnly bit
	,@CustomWhere nvarchar(max)

-- Veja a descrição abaixo para entender melhor como usar esses parâmetros!

-- Especifique aqui uma data de referencia. Somente os backups a partir dessa data serão considerados!
SET @RefDate			= DATEADD(MONTH,-6,GETDATE())

-- Controla como será exibido os resultados 
-- 1 - Será exibido um resultado detalhado, onde você poderá ver por banco, etc.
-- 2 - Será feito um resumo. Nesse modo alguns parâmetros abaixo são ignorados.
SET @reporttype			= 1	

-- Especifica um periodo (os mesmos valores aceitáveis pela função DATEDIFF).
SET @period				= 'DAY';		

-- Se 1, o resultado final será gerado por banco de dados. Se 0, será agrupado pra instância inteira.
SET @GroupByDB			= 1;			--> If 1, groups by database. If 0, groups all in instance.

-- Se 1, agrupa pelo período (por exemplo, você vai ter os backups feitos no mesmo dia). Se 0, ignora o período.
SET @groupPeriod		= 0;

-- Considera backups COPY_ONLY. Geralmente, para volumetria de produção, você não quer saber estes.
SET @considerCopyOnly	= 0;

--> Cláusula where cusotmizada para ser aplicada na tabela backupset.
-- Permite que você usa um filtro personalizado para escolher quais backups considerar.
SET @CustomWhere		= NULL;			--> You can write a custom msdb filter. This filter will be applied before filters above.

/*
	Descrição dos resultados:


		@ReportType = 1 (detalhado)
			No modo 1, o script vai coletar todos os backups feitos desde @RefData.
			O script vai agrupar por tipo de backup (coluna type de msdb..backupset).
		
			Se você especificar @GroupByDB = 1, o script também agrupa por banco de dados.
			Se você especificar @GroupByPeriod = 1, o script vai agrupar pelo período especificado em @Period.
			
			A coluna BackupPeriod representa esse período.
			Por exemplo, se @Period é 'MONTH', e o backup foi feito em '2024-01-31 00:18:20.000', BackupPeriod será '2024-01-01'.
			
			Você pode combinar @groupPeriod e @GroupByDB. As possibilidades são:
				@GroupByDB = 1 @groupPeriod =1
					Isso vai mostrar  as info de backup por banco e por período, desde @RefData. É útil para uma visão detalhada.
				@GroupByDB = 1 @groupPeriod = 0
					Isso vai mostrar as informações por banco, desde @RefData. Útil para uma visão de cada banco.
				@GroupByDB = 0 @groupPeriod = 1
					Isso vai mostrar todos os backups agrpados por período, desde @RefData.
					Útil para uma visão geral da instância e em período específicos (mensal, por hora, semanal, etc.)
				@GroupByDB = 0 @groupPeriod = 0	
					Isso via mostrar uma visão geral da instância, desde @RefDate.
					


			Colunas:

				ServerInstance			- Nome da instância
				BackupSource			- Nome do banco. Será null se @GroupByDB = 0
				BackupPeriod			- A primeira data/hora do período. Exemplo: se @period = MONTH, então YEAR-MONTH-01 00:00:00. 
											Se @period = DAY, então YEAR-MONTH-DAY 00:00:00
				type					- Tipo de backup (mesmo de msdb..backupset)
				lastBackup				- A data do último backup nesse período. Se @groupPeriod = 0, então será a data do último backup.
				backupSize				- O tamanho total em MB
				avgSize					- Tamanho médio de cada backup no período.
				backupCompressedSize	- Tamanho total do backup, comprimido, em MB
				avgCompressedSize		- Tamanho médio de cada backup comprimido
				backupCount				- Quantidade total de backups feitas
				CompressionSavings		- Taxa de compressão. Exemplo: 0.79 é 79% de compressão. Formula  1-(backupCompressedSize/backupSize)

		@ReportType = 2

			In this mode, script will agregates information by period. Using this options enable @groupByPeriod automatically.
			The script will groups data by period, then groups by database or not.
			
			Neste modo o script vai agregar a informação por período. 
			Habilitando esse modo, automaticamente, habilita @GroupPeriod.
			
			O script primeiro agrupa por período, e depois por banco (se @groupByDb = 1).
			Esse modo é bem útil para ver a periodicidade de backup e responde perguntas do tipo:
				- Quanto de backup faço por período? (por dia, por mês, etc.)
				- E, você pode responder para um banco específico
			

			Columns:

				BackupSource					- Nome do banco, se @groupByDB = 1
				type							- Tipo de Backup
				Periodicity						- Periodicidade. Baseado em @Period. Se @Period é MONTH, significa "mensal" (mas a coluna mostrará o mesmo valor de @period). Aqui é interessante entender que é como se você estivesse querendos saber quando de backup eu tenho "mensalmente" para esta instancia ou essa base? Ou "diariamente"
				LastOnPeriod					- Último backup feito desde @RefDate
				AvgSizeOnPeriodicity			-Tamanho médio do backup feito no periodo, em MB. Exemplo, se periodicity é MONTH (mensal), e essa coluna mostra o valor 100000, isso significa que foi uma média de 100GB por mês
				AvgCompressedSizeOnPeriodicity	- O mesmo que o anterior, porém considerando o tamanho comprimido.
				BackupCountOnPeriod				- Total de backups desde @RefDate.
				AvgCountPerPeriodicity			- Quantidade média feita no período.Por exemplo, se periodicity é MONTH (mensal), e essa coluna mostra 1000, isso significa que foi uma média de 1000 backups por mês!
*/

---------

IF OBJECT_ID('tempdb..#BackupFinalData') IS NOT NULL
	DROP TABLE #BackupFinalData;

IF OBJECT_ID('tempdb..#BackupInfo') IS NOT NULL
	DROP TABLE #BackupInfo;

	CREATE TABLE #BackupInfo(
		 backup_set_id bigint
		,database_name sysname
		,backup_finish_date datetime
		,type varchar(5)
		,backup_size numeric(20,0)
		,compressed_backup_size numeric(20,0)
	
	)

-- Validations...
	IF @reporttype = 2
		SET @groupPeriod = 1;

	IF LEN(@CustomWhere ) = 0
		SET @CustomWhere = NULL;

-- BackupPeriod: Maps a date to a specific period based on passed parameters.
IF OBJECT_ID('tempdb..#BackupPeriod') IS NOT NULL
	DROP TABLE #BackupPeriod;

	CREATE TABLE #BackupPeriod(
		originalDate datetime	-- Represent the original date
		,periodDate datetime	-- Represent the date in the period requested
	)
	



DECLARE 
	@cmd nvarchar(4000)
	,@compressedExpr nvarchar(100)
	,@copyOnly nvarchar(500)
	,@sqlVersion int
;

-- Getting SQL Version
SELECT @sqlVersion = LEFT(V.Ver,CHARINDEX('.',V.Ver)-1) FROM (SELECT  CONVERT(varchar(30),SERVERPROPERTY('ProductVersion')) as Ver) V


-- If supports compression, then add compression column.

IF EXISTS(SELECT * FROM msdb.INFORMATION_SCHEMA.COLUMNS C WHERE C.TABLE_NAME = 'backupset' AND COLUMN_NAME = 'compressed_backup_size')
	SET @compressedExpr = 'BS.compressed_backup_size';
ELSE
	SET @compressedExpr = 'BS.backup_size';

IF EXISTS(SELECT * FROM msdb.INFORMATION_SCHEMA.COLUMNS C WHERE C.TABLE_NAME = 'backupset' AND COLUMN_NAME = 'is_copy_only')
	SET @copyOnly = 'BS.is_copy_only = 0';
ELSE
	SET @copyOnly = NULL;

IF ISNULL(@considerCopyOnly,0) = 1
	SET @copyOnly = NULL;

--> Query for collect base backup data
SET @cmd = N'
	INSERT INTO
		#BackupInfo
	SELECT -- The DISTINCT remove duplicates generated by join
		 BS.backup_set_id
		,BS.database_name
		,BS.backup_finish_date
		,BS.type
		,BS.backup_size
		,'+@compressedExpr+' as compressedSize
	FROM	
		(
			SELECT
				*
			FROM
				msdb.dbo.backupset BS
			WHERE
				1 = 1
			-- #CustomWhereFilter
				'+ISNULL(' AND ('+@CustomWhere+')','')+'
		) BS
	WHERE
		BS.backup_finish_date >= @RefDate

		'+ISNULL('AND '+@copyOnly,'')+'
'
-- Run Query!
EXEC sp_executesql @cmd,N'@RefDate datetime',@RefDate;



-- Converting backup dates to period dates...
DECLARE @PeriodMinutes int;

SET @cmd = N'
	SET @PeriodMinutes = DATEDIFF(MI,''19000101'',DATEADD('+@period+',1,''19000101'')) 

	INSERT INTO
		#BackupPeriod
	SELECT
		D.backup_finish_date AS originalDate
		,DATEADD('+@period+',DATEDIFF('+@period+',''19000101'',D.backup_finish_date),''19000101'') as periodDate
	FROM
		(
			SELECT DISTINCT 
				backup_finish_date
			FROM
				#BackupInfo BI
		) D
';
EXEC sp_executesql @cmd,N'@PeriodMinutes int OUTPUT',@PeriodMinutes OUTPUT;


SELECT
	 @@SERVERNAME as ServerInstance
	,B.BackupSource
	,B.BackupPeriod
	,B.type
	,MAX(B.backup_finish_date)										lastBackup
	,CONVERT(decimal(17,2),SUM(backup_size/1024/1024))				backupSize
	,CONVERT(decimal(17,2),AVG(backup_size/1024/1024))				avgSize
	,CONVERT(decimal(17,2),SUM(compressed_backup_size/1024/1024))	backupCompressedSize
	,CONVERT(decimal(17,2),AVG(compressed_backup_size/1024/1024))	avgCompressedSize
	,CONVERT(bigint,COUNT(backup_set_id))							backupCount
INTO
	#BackupFinalData
FROM
(
	SELECT	
		CASE
			WHEN @groupPeriod = 1 THEN BP.periodDate
			ELSE NULL
		END BackupPeriod
		,CASE
			WHEN @GroupByDB = 1 THEN BI.database_name
			ELSE NULL
		END as BackupSource
		,BI.*
	FROM
		#BackupInfo BI
		INNER JOIN
		#BackupPeriod BP
			ON BP.originalDate = BI.backup_finish_date
) B
GROUP BY
	 B.BackupSource
	,B.BackupPeriod
	,B.type

IF @reporttype = 1 --'PERIOD_DETAILED'
	SELECT
		*
		,1-CONVERT(decimal(3,2),backupCompressedSize/backupSize) as CompressionSavings
	FROM
		#BackupFinalData BFD
	ORDER BY
		 BFD.BackupSource
		,BFD.BackupPeriod
		,BFD.type

IF @reporttype = 2 --'PERIOD_STATS'
	SELECT
		PS.*
		,AvgFreq = F.Formmatted
	FROM
		(
			SELECT
				 BFD.BackupSource
				,BFD.type
				,@period			As Periodicity
				,MAX(lastBackup)	aS LastOnPeriod
				,AVG(backupSize)	AS AvgSizeOnPeriodicity
				,AVG(backupCompressedSize)	AS AvgCompressedSizeOnPeriodicity
				,COUNT(*) AS Periods
				,SUM(backupCount)	AS BackupCountOnPeriod
				,CEILING(AVG(backupCount*1.))	AS AvgCountPerPeriodicit
			FROM
				#BackupFinalData BFD
			GROUP BY
				 BFD.BackupSource
				,BFD.type
				
				WITH ROLLUP
		) PS
		CROSS APPLY (
			SELECT
					Formmatted = ISNULL(NULLIF(t.Y+'y','0y'),'')
					+ISNULL(NULLIF(t.Mo+'mo','0mo'),'')
					+ISNULL(NULLIF(t.D+'d','0d'),'')
					+ISNULL(NULLIF(t.H+'h','0h'),'')
					+ISNULL(NULLIF(t.M+'m','0m'),'')
					+ISNULL(NULLIF(t.S+'s','0s'),'') 
				FROM
				(
					SELECT	
						 CONVERT(varchar(10),(FC.AvgFreq%60))			as S
						,CONVERT(varchar(10),(FC.AvgFreq/60)%60)		as M
						,CONVERT(varchar(10),(FC.AvgFreq/3600)%24)		as H
						,CONVERT(varchar(10),(FC.AvgFreq/86400)%30)	as D
						,CONVERT(varchar(10),(FC.AvgFreq/2592000)%12)	as Mo
						,CONVERT(varchar(10),(FC.AvgFreq/31104000))	as Y
					FROM
						(
							SELECT AvgFreq = CONVERT(int,@PeriodMinutes/AvgCountPerPeriodicit)*60
						) FC
				) t
		) F
	ORDER BY
		BackupSource
		,type	


