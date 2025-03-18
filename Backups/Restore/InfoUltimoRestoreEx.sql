/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Informações de data de restore


*/
SELECT
	*
FROM
	(
		SELECT DISTINCT
			RH.destination_database_name as name
		FROM
			msdb..restorehistory RH
	) D
	OUTER APPLY
	(
		SELECT TOP 1
			BS.backup_finish_date	as DataDosDados
			,RH.restore_date		as DataExecucaoRestore
		FROM
			msdb..restorehistory RH
			INNER JOIN
			msdb..backupset BS
				ON BS.backup_set_id = RH.backup_set_id
		WHERE
			RH.destination_database_name = D.name
		ORDER BY
			RH.restore_date DESC
	) RH
--WHERE
--	D.NAME in ('master') --> nome dos bancos

