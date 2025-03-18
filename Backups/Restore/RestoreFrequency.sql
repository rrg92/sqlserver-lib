/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Traz informações da frequência de restore de um banco


*/

SELECT
	d.NAME
	,RF.AvgRestorePeerWeek
FROM
	sys.databases D
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