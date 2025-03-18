/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Uma das primeiras versões que criei para obter o tamanho do último backup!


*/
SELECT
	*
FROM
	(
		SELECT
			BS.database_name
			,BS.type
			,BS.backup_finish_date
			,BS.compressed_backup_size/1024.00/1024.00 AS TamMB
			,ROW_NUMBER() OVER(PARTITION BY BS.database_name,BS.type ORDER BY BS.backup_finish_date DESC) as LastRn
		FROM
			msdb.dbo.backupset BS
			INNER JOIN
			msdb.dbo.backupmediaset MS
				ON MS.media_set_id = BS.media_set_id
				AND BS.is_copy_only = 0
	) BL
WHERE
	BL.LastRn = 1