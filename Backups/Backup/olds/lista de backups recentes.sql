/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Um dos primeiro scripts para obter a lista de backups dos bancos!


*/

SELECT DISTINCT
	 bs.database_name
	,bs.type 
	,bs.backup_finish_date
	,REVERSE( 
			LEFT ( 
					 REVERSE(bmf.physical_device_name)
					,CHARINDEX( '\',REVERSE(bmf.physical_device_name)) - 1
				)  
			) as NomeBackup
FROM
				msdb..backupset			bs
	INNER JOIN	msdb..backupmediafamily	bmf	on	bmf.media_set_id = bs.media_set_id
WHERE
		bs.type				= 'D'	
	AND bs.backup_finish_date in --> Faz o filtro somente pelo último backup de cada banco
		(
			SELECT
				max( bsex.backup_finish_date  )
			FROM
				msdb..backupset bsex
			WHERE
					bsex.database_name	= bs.database_name
				and	bsex.type			= bs.type	
		)
ORDER BY
	bs.database_name
	

	
--select * from backupmediafamily
