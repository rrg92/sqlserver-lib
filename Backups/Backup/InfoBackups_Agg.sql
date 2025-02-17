/*#info 

	# autor 
		Rodrigo ribeiro gomes

	# Detalhes 
		Outro script para trazer info rápida de backups dos bancos.
		Você vai notar (ou já deve ter notado) que existem variações desse aqui nessa pasta...
		
		

*/

SELECT
	D.name
	,COUNT(CASE WHEN BS.type = 'D' AND BS.is_copy_only = 0 THEN BS.backup_set_id END) as TotalBackupsFull
	,COUNT(CASE WHEN BS.type = 'I' AND BS.is_copy_only = 0 THEN BS.backup_set_id END) as TotalBackupsDiff
	,COUNT(CASE WHEN BS.type = 'L' AND BS.is_copy_only = 0 THEN BS.backup_set_id END) as TotalBackupsLog
	,MAX(CASE WHEN BS.type = 'D' AND BS.is_copy_only = 0 THEN BS.backup_finish_date END) as LastBackupFull
	,MAX(CASE WHEN BS.type = 'I' AND BS.is_copy_only = 0 THEN BS.backup_finish_date END) as LastBackupDiff
	,MAX(CASE WHEN BS.type = 'L' AND BS.is_copy_only = 0 THEN BS.backup_finish_date END) as LastBackupLog
	,COUNT(CASE WHEN BS.type = 'D' AND BS.is_copy_only = 0 AND MS.is_compressed = 1 THEN BS.backup_set_id END) as TotalBackupsFullCompressed
	,COUNT(CASE WHEN BS.type = 'I' AND BS.is_copy_only = 0 AND MS.is_compressed = 1 THEN BS.backup_set_id END) as TotalBackupsDiffCompressed
	,COUNT(CASE WHEN BS.type = 'L' AND BS.is_copy_only = 0 AND MS.is_compressed = 1 THEN BS.backup_set_id END) as TotalBackupsLogCompressed
	,SUM(CASE WHEN BS.type = 'D' AND BS.is_copy_only = 0 THEN BS.compressed_backup_size END)/1024.00/1024.00 as TamanhoBackupsFull
	,SUM(CASE WHEN BS.type = 'I' AND BS.is_copy_only = 0 THEN BS.compressed_backup_size END)/1024.00/1024.00  as TamanhoBackupsFull
	,SUM(CASE WHEN BS.type = 'L' AND BS.is_copy_only = 0 THEN BS.compressed_backup_size END)/1024.00/1024.00  as TamanhoBackupsFull
FROM
	sys.databases D
	LEFT JOIN 
	(
		msdb.dbo.backupset BS
		INNER JOIN
		msdb.dbo.backupmediaset MS
			ON MS.media_set_id = BS.media_set_id
			AND BS.is_copy_only = 0
	)
		ON BS.database_name = D.name
GROUP BY
	D.name
ORDER BY
	D.name