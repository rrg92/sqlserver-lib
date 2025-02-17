/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Esse foi um script que fiz para facilitar o acesso a info de backups de qualquer banco.
		Eu nem lembro pq deixei em ingles, eu acho que era pela prática (vide pelá péssima gramática e sintaxe).

		Acho que após esse script,e u fiz outros melhores, mas, mantive aqui pois há algumas técnicas legais que usei para resolver algumas coisinhas.
		Fica de referência e quem sabe não uso futuramente em alguns novos scripts

		A palavra "Latency" do nome do arquivo acho que foi usada incorremtanete...
		O objetivo principal era responder: "Tem quanto tempo que não faço um backup X do banco B?"

*/

USE master
GO

IF OBJECT_ID('dbo.sp_CheckLastBackup') IS NULL
	EXEC('CREATE PROCEDURE sp_CheckLastBackup AS SELECT 0 AS StubVersion');
	EXEC sp_MS_marksystemobject sp_CheckLastBackup;
GO

ALTER PROCEDURE sp_CheckLastBackup
(
		 @LatencyFULL		varchar(100)	= '7 DAY'
		,@LatencyDIFF		varchar(100)	= '1 DAY'
		,@LatencyLOG		varchar(100)	= '1 HOUR'
		,@MediaFilter		varchar(8000)	= '%'
		,@IncludeCopyOnly	bit				= 0
		,@LatencyTable		varchar(250)	= NULL
		,@LatencyTableXML	varchar(8000)	= NULL
)
AS

/**
	This scripts validates backups by checking the time passed since last backup time. This time difference is the latency.
	You can specify the time that you can validate by backup type or by database. This time is called the CheckLatency.

	If latency of a specific database is out of CheckLatency, then this database/backyp type pair is marked as invalid.
	The action take for invalid is send a report. Futher, new actions can be add.

	Latency Expressions
		Latency expressions are simply a way of you specify the check latency.
		You make this by using same values are DATEDIFF function.
		For example, you can specify latencies of  7 DAY, 1 MONTH, 5 WEEK.

**/
	-- TestParams...
	--DECLARE 
	--	 @Database sysname
	--	,@LatencyFULL	varchar(100)
	--	,@LatencyDIFF	varchar(100)
	--	,@LatencyLOG	varchar(100)
	--	,@MediaFilter	varchar(8000)
	--	,@IncludeCopyOnly bit
	--	,@LatencyTable		varchar(250)
	--	,@LatencyTableXML	varchar(8000)

	--SET @LatencyFULL	= '7 DAY';
	--SET @LatencyDIFF	= '1 DAY';
	--SET @LatencyLOG		= '1 HOUR';
	--SET @MediaFilter	= '%'
	--SET @IncludeCopyOnly = 0;
	--SET @LatencyTableXML = '<db name="SGE" Log="15 MINUTE"/>'

-- Will will store latency infomration on this table.
DECLARE
	@LatencyNumber int
	,@LatencyPeriod varchar(100)
	,@FullTimeLimit datetime
	,@DiffTimeLimit datetime
	,@LogTimeLimit datetime
	,@tsql nvarchar(4000)
	,@tsql_CopyOnly nvarchar(200)

IF OBJECT_ID('tempdb..#DatabaseLatency') IS NOT NULL
	DROP TABLE #DatabaseLatency;
CREATE TABLE #DatabaseLatency(id int NOT NULL PRIMARY KEY IDENTITY,databaseName varchar(200) UNIQUE, FullExpr varchar(100), DiffExpr varchar(100), LogExpr varchar(100), FullBaseTime datetime, DiffBaseTime datetime, LogBaseTime datetime)


-- This is implemented as a varchar for comptaibility reasons with sql 2000. XML data type dont exists on 2000...
IF @LatencyTableXML IS NOT NULl 
BEGIN
	-- XML FORMAT: <db name="DatabaseName" Full="" Diff="" Log="" />
	SET @tsql = '
		DECLARE @XMLTable XML;
		SET @XMLTable = CONVERT(XML,@LatencyXML)

		SELECT
			 DBNodes.x.value(''@name'',''varchar(200)'')
			,DBNodes.x.value(''@Full'',''varchar(100)'')
			,DBNodes.x.value(''@Diff'',''varchar(100)'')
			,DBNodes.x.value(''@Log'',''varchar(100)'')
		FROM
			@XMLTable.nodes(''//db'') DBNodes(x)
	'

	INSERT INTO #DatabaseLatency(databaseName,FullExpr,DiffExpr,LogExpr) EXEC sp_executesql @tsql,N'@LatencyXML varchar(8000)',@LatencyTableXML;

END ELSE IF OBJECT_ID(@LatencyTable) IS NOT NULL
BEGIN
	SET @tsql = 'SELECT * FROM '+@LatencyTable;
	INSERT INTO #DatabaseLatency(databaseName,FullExpr,DiffExpr,LogExpr)  EXEC sp_executesql @tsql;
END



-- If a default isnot rpesent, insert the paraemters...
IF NOT EXISTS(SELECT * FROM #DatabaseLatency WHERE databaseName IS NULL)
	INSERT INTO #DatabaseLatency(FullExpr,DiffExpr,LogExpr) VALUES(@LatencyFULL,@LatencyDIFF,@LatencyLOG)

DECLARE 
	@CurrentId int
	,@col_FullExpr varchar(100)
	,@col_DiffExpr varchar(100)
	,@col_LogExpr varchar(100)
SET @CurrentId = 1;

WHILE EXISTS(SELECT * FROM #DatabaseLatency WHERE id >= @CurrentId)
BEGIN
	SELECT
		 @col_FullExpr = 	FullExpr 
		,@col_DiffExpr = 	DiffExpr 
		,@col_LogExpr = 	LogExpr 
	FROM 
		#DatabaseLatency 
	WHERE 
		id = @CurrentId

	--First, remove extra spaces...
	SET @col_FullExpr = REPLACE(REPLACE(REPLACE(@col_FullExpr, ' ', '*^'), '^*', ''), '*^', ' ');
	SET @col_DiffExpr = REPLACE(REPLACE(REPLACE(@col_DiffExpr, ' ', '*^'), '^*', ''), '*^', ' ');
	SET @col_LogExpr = REPLACE(REPLACE(REPLACE(@col_LogExpr, ' ', '*^'), '^*', ''), '*^', ' ');

	-- Next, lets separate number  and data part...
	SET @LatencyNumber = LEFT(@col_FullExpr,CHARINDEX(' ',@col_FullExpr))
	SET @LatencyPeriod = RIGHT(@col_FullExpr,LEN(@col_FullExpr)-CHARINDEX(' ',@col_FullExpr))
	SET @tsql  = 'SET @ReturnValue = DATEADD('+@LatencyPeriod+',-@LatencyNumber,CURRENT_TIMESTAMP)'
	EXEC sp_executesql @tsql,N'@ReturnValue datetime OUTPUT,@LatencyNumber int',@FullTimeLimit OUTPUT,@LatencyNumber ;

	-- Next, lets separate number  and data part...
	SET @LatencyNumber = LEFT(@col_DiffExpr,CHARINDEX(' ',@col_DiffExpr))
	SET @LatencyPeriod = RIGHT(@col_DiffExpr,LEN(@col_DiffExpr)-CHARINDEX(' ',@col_DiffExpr))
	SET @tsql  = 'SET @ReturnValue = DATEADD('+@LatencyPeriod+',-@LatencyNumber,CURRENT_TIMESTAMP)'
	EXEC sp_executesql @tsql,N'@ReturnValue datetime OUTPUT,@LatencyNumber int',@DiffTimeLimit OUTPUT,@LatencyNumber ;

	-- Next, lets separate number  and data part...
	SET @LatencyNumber = LEFT(@col_LogExpr,CHARINDEX(' ',@col_LogExpr))
	SET @LatencyPeriod = RIGHT(@col_LogExpr,LEN(@col_LogExpr)-CHARINDEX(' ',@col_LogExpr))
	SET @tsql  = 'SET @ReturnValue = DATEADD('+@LatencyPeriod+',-@LatencyNumber,CURRENT_TIMESTAMP)'
	EXEC sp_executesql @tsql,N'@ReturnValue datetime OUTPUT,@LatencyNumber int',@LogTimeLimit OUTPUT,@LatencyNumber ;

	UPDATE 
		#DatabaseLatency
	SET
		FullBaseTime	= @FullTimeLimit
		,DiffBaseTime	= @DiffTimeLimit
		,LogBaseTime	= @LogTimeLimit
	WHERE
		id = @CurrentId

	SET @CurrentId = @CurrentId + 1;
END




-- Get last backups...
IF OBJECT_ID('tempdb..#BackupInfo') IS NOT NULL
	DROP TABLE #BackupInfo;
CREATE TABLE #BackupInfo(database_name sysname, type varchar(5), backup_finish_date datetime)

IF OBJECT_ID('tempdb..#DatabaseLastBackups') IS NOT NULL
	DROP TABLE #DatabaseLastBackups;


IF EXISTS(SELECT * FROM msdb.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'backupset' AND COLUMN_NAME = 'is_copy_only')
BEGIN
	SET @tsql_CopyOnly = 'BS.copy_only = 0';

	IF @IncludeCopyOnly = 0
		SET @tsql_CopyOnly = NULL;
END



SET @tsql = N'
SELECT
	BS.database_name
	,BS.type
	,BS.backup_finish_date
FROM
	msdb..backupset BS
WHERE
	BS.backup_set_id = (
		SELECT TOP 1
			BS2.backup_set_id
		FROM
			msdb..backupset BS2
		WHERE
			BS2.database_name = BS.database_name
			AND
			BS2.type = BS.type
			AND
			EXISTS (
				SELECT
					*
				FROM
					msdb..backupmediafamily BMF
				WHERE
					BMF.media_set_id = BS2.media_set_id
					AND
					BMF.physical_device_name like @MediaFilter
			)
		ORDER BY
			BS2.backup_set_id DESC
	)

	'+ISNULL('AND'+@tsql_CopyOnly,'')+'
'

INSERT INTO  #BackupInfo
EXEC sp_executesql @tsql,N'@MediaFilter varchar(8000)',@Mediafilter;

SELECT	
	D.NAME
	,BI.*
INTO
	#DatabaseLastBackups
FROM
	sysdatabases D
	LEFT JOIN
	(
		SELECT
			BI.database_name
			,MAX(CASE WHEN BI.type = 'D' THEN BI.backup_finish_date END) as LastFullBackup
			,MAX(CASE WHEN BI.type = 'I' THEN BI.backup_finish_date END) as LastDiffBackup
			,MAX(CASE WHEN BI.type = 'L' THEN BI.backup_finish_date END) as LastLogBackup
		FROM
			#BackupInfo BI
		GROUP BY
			BI.database_name
	) BI
		ON BI.database_name = D.name
WHERE
	d.name not in ('tempdb','model')
	AND
	(ISNULL(DATABASEPROPERTYEX(d.name,'IsOffline'),0) = 0 AND ISNULL(DATABASEPROPERTYEX(d.name,'Status'),'ONLINE') = 'ONLINE' )

IF OBJECT_ID('tempdb..#BackupStatus') IS NOT NULL
	DROP TABLE #BackupStatus;

SELECT
	DLB.*
	,ISNULL(DLT.FullBaseTime,DLTDEF.FullBaseTime) FullBaseTime
	,ISNULL(DLT.DiffBaseTime,DLTDEF.DiffBaseTime) DiffBaseTime
	,ISNULL(DLT.LogBaseTime,DLTDEF.LogBaseTime) LogBaseTime
	,CASE
		WHEN ISNULL(LastFullBackup,0) < ISNULL(DLT.FullBaseTime,DLTDEF.FullBaseTime) THEN 1 
		ELSE 0
	END as FullOutOfTime
	,CASE
		WHEN ISNULL(LastDiffBackup,0) < ISNULL(DLT.DiffBaseTime,DLTDEF.DiffBaseTime) THEN 1 
		ELSE 0
	END as DiffOutOfTime
	,CASE
		WHEN ISNULL(LastLogBackup,0) < ISNULL(DLT.LogBaseTime,DLTDEF.LogBaseTime) THEN 1 
		ELSE 0
	END as LogOutOfTime
INTO
	#BackupStatus
FROM	
	#DatabaseLastBackups DLB
	LEFT JOIN
	#DatabaseLatency DLTDEF
		ON DLTDEF.databaseName	IS NULL
	LEFT JOIN
	#DatabaseLatency DLT
		ON DLT.databaseName	= DLB.database_name


SELECT
	*
FROM
	#BackupStatus BS
WHERE
	BS.FullOutOfTime = 1
	OR
	BS.LogOutOfTime = 1
	OR
	BS.DiffOutOfTime = 1

