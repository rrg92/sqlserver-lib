/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Uma das primeiras versões que criei para obter info de backup


*/

DECLARE
	@Ontem datetime
	,@Hoje datetime
;
SET @Ontem = CONVERT(VARCHAR(8),CURRENT_TIMESTAMP-1,112)
SET @Hoje = CONVERT(VARCHAR(8),CURRENT_TIMESTAMP,112)

SELECT
	D.name
	,B.*
FROM
	sys.databases D 
	OUTER APPLY
	(
		SELECT	
			COUNT(*) as TotalBacukups
			,MAX(CASE WHEN BS.type = 'D' THEN BS.backup_finish_date END) as LastBackupFull
			,MAX(CASE WHEN BS.type = 'I' THEN BS.backup_finish_date END) as LastBackupDiff
			,MAX(CASE WHEN BS.type = 'L' THEN BS.backup_finish_date END) as LastBackupLog
			,MAX(CASE WHEN BS.Seq = 1 AND BS.type = 'L' THEN BS.backup_finish_date END) as LastBackupLogAntesHoje
		FROM
			(
				SELECT
					*
					,CASE 
						WHEN BS.backup_finish_date < @Hoje THEN ROW_NUMBER() OVER( PARTITION BY BS.name,BS.type ORDER BY CONVERT(datetime,CONVERT(VARCHAR(8),BS.backup_finish_date,112)) DESC )
						ELSE NULL
					END as Seq
				FROM
					msdb.dbo.backupset BS
				WHERE
					BS.database_name = D.name
			) BS
		WHERE
			BS.database_name = D.name
	) B
OPTION(RECOMPILE)