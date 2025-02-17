/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Report simples e rápido para saber o último backup de cada base por tipo.  
		Uso esse quando eu quero uma visã rápida e simples se o backup está sendo feito!
		
		Somente banco que estão ONLINE.

*/
IF OBJECT_ID('tempdb..#BackupInfo') IS NOT NULL
	DROP TABLE #BackupInfo;

IF OBJECT_ID('tempdb..#DatabaseLastBackups') IS NOT NULL
	DROP TABLE #DatabaseLastBackups;

SELECT
	BS.database_name
	,BS.type
	,BS.backup_finish_date
INTO
	#BackupInfo
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
			)
			AND BS2.is_copy_only = 0
		ORDER BY
			BS2.backup_set_id DESC
	)


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

SELECT
	*
	,DATEDIFF(DAY,LastFullBackup,CURRENT_TIMESTAMP) TimePassedFull
FROM	
	#DatabaseLastBackups
ORDER BY
	LastFullBackup


