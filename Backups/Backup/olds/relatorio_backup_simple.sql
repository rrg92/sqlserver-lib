/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Mais uma versão para obter info de backup e datas!


*/

SELECT
	*
FROM
(
	SELECT
		*
		,DATEDIFF(dd,B.LastBackupFull,CURRENT_TIMESTAMP) as DiaUltimoFull
		,DATEDIFF(dd,B.LastBackupDiff,CURRENT_TIMESTAMP) as DiaUltimoDiff
		,DATEDIFF(Mi,B.LastBackupLog,CURRENT_TIMESTAMP) as MinutosUltimoLog
	FROM
	(
		SELECT
			D.name
			--,MAX(CASE WHEN BS.Seq = 1 THEN BMF.physical_device_name END) as Caminho
			,MAX(CASE WHEN BS.type = 'D' THEN BS.backup_finish_date END) as LastBackupFull
			,MAX(CASE WHEN BS.type = 'I' THEN BS.backup_finish_date END) as LastBackupDiff
			,MAX(CASE WHEN BS.type = 'L' THEN BS.backup_finish_date END) as LastBackupLog
		FROM
			sys.databases D 
			LEFT JOIN
			(
				SELECT
					*
					--,ROW_NUMBER() OVER(PARTITION BY BS.database_name,BS.type ORDER BY BS.backup_finish_date DESC) Seq
				FROM
					msdb.dbo.backupset BS
			) BS
				ON BS.database_name = D.name
				AND BS.is_copy_only = 0
			--LEFT JOIN
			--msdb.dbo.backupmediafamily BMF
			--	ON BMF.media_set_id = BS.media_set_id
		WHERE
			D.name NOT IN ('model','tempdb')
		GROUP BY
			D.name
	) B
) F 
ORDER BY
	DiaUltimoFull DESC
	

