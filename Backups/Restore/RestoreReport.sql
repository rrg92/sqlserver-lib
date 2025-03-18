/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Informações de restore de um banco específico ou com algum outro critério de filtros.


*/

SELECT
	 rh.destination_database_name as DatabaseName
	,RH.restore_date	as DataExecucaoRestore
	,Bs.backup_finish_date as DataBackup
FROM
	msdb..restorehistory RH JOIN msdb..backupset BS ON BS.backup_set_id = RH.backup_set_id
WHERE
	--> Filtros para refinar 
	
	rh.destination_database_name = 'master' --> Nome do Banco
	--AND
	--RH.user_name = 'UserRestore' 
ORDER BY
	RH.restore_date DESC