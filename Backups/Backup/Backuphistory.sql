/*#info 
	
	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Traz o histórico de backups de um banco específico, junto com o local. 
		Útil para ter uma visão um pouco mais detalhada e rápida de como os backups estão sendo feitos, quando e onde foram feitos.

*/

SELECT
	 BS.backup_set_id
	,BS.database_name
	,BS.backup_finish_date
	,BS.type
	,BS.is_copy_only
	,MF.destination
	,DaysAgo = DATEDIFF(DAY,backup_finish_date,CURRENT_TIMESTAMP) 
FROM
	msdb..backupset BS
	OUTER APPLY
	(
		SELECT
			BMF.physical_device_name+NCHAR(13)+NCHAR(10)
		FROM
			msdb..backupmediafamily BMF
		WHERE
			BMF.media_set_id = BS.media_set_id
		FOR XML PATH(''),TYPE
	) MF(destination)

WHERE --> Ajusto manualmente os filtros conforme o caso!

	BS.database_name = 'master'	--> coloque aqui os bancos que quer consultar
	AND
	BS.is_copy_only = 0						
	AND
	BS.type = 'D' --> somente full, mas pode ajustar, ex,: bs.type in ('L','D')
ORDER BY
	BS.backup_set_id DESC