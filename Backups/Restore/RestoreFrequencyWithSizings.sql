/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Traz informações da frequência de restoe de um banco


*/

IF OBJECT_ID('tempdb..#TamanhoBancos') IS NOT NULL
	DROP TABLE #TamanhoBancos;

CREATE TABLE
	#TamanhoBancos( Banco sysname, TamanhoTotalPag int, TamanhoUsadoPag int );
	
EXEC sp_MSforeachdb '
	USE [?];
	
	INSERT INTO #TamanhoBancos
	SELECT
	 db_name()
	 ,SUM(size) 
	 ,SUM(FILEPROPERTY(name,''SpaceUsed''))
	FROM
		sys.database_files
'

SELECT
	d.NAME
	,RF.AvgRestorePeerWeek
	,TB.TamanhoUsadoPag/128.00
FROM
	sys.databases D
	JOIN
	#TamanhoBancos TB
		ON TB.Banco = D.name
	LEFT JOIN
	(
		SELECT
			RG1.DatabaseName
			,RestoreCount
			,AvgRestorePeerWeek = ISNULL(RestoreCount/NULLIF(ElapsedTime,0),0)
			,LastRestore
			,FirstRestore
		FROM
			(
				SELECT
					RR.DatabaseName
					--,RR.StartWeek
					,RestoreCount	= COUNT(*)
					,LastRestore	= MAX(RR.RestoreDate)
					,FirstRestore	= MIN(RR.RestoreDate)
					,ElapsedTime	= DATEDIFF(WK,MIN(RR.RestoreDate),CURRENT_TIMESTAMP)
				FROM
					(
						SELECT
								DatabaseName	= RH.destination_database_name
							,RestoreDate	= RH.restore_date
							,StartWeek		= DATEADd(WK,DATEDIFF(WK,0,RH.restore_date),0)-1
						FROM
							msdb..restorehistory RH
						WHERE
							RH.restore_type = 'D'
							AND
							RH.restore_date >= '20160101'
					) RR
				GROUP BY
					RR.DatabaseName
					--,RR.StartWeek
			) RG1
	) RF
		ON RF.DatabaseName = D.name
WHERE
	D.database_id > 4
	AND
	ISNULL(RF.AvgRestorePeerWeek,0) = 0