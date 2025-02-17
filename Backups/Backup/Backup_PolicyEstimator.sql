/*#info 

	# autor 
		Rodrigo ribeiro gomes

	# Detalhes 
		Esse aqui eu nao lembro, mas pelo nome, foi alguma tentativa frustada de criar algo que estimasse a politica de backup, com base no log.
		Mantendo aqui para , quem sabe, um dia, voltar e terminar!
		
		

*/


;WITH backups AS
(
	SELECT
		 BS.backup_set_id
		,BS.database_name
		,BS.type
		,BS.backup_finish_date
	FROM
		msdb.dbo.backupset BS
	WHERE
		BS.type IN ('L')
		AND
		BS.backup_finish_date >= '20150601' AND BS.backup_finish_date < '20150701'
		AND
		BS.is_copy_only = 0
)
SELECT
	BS.*
	,BSA.backup_finish_date
	,DATEDIFF(MINUTE,BSA.backup_finish_date,BS.backup_finish_date)		DiffMinutes
	,DATEDIFF(HOUR,BSA.backup_finish_date,BS.backup_finish_date)		DiffHours
	,DATEDIFF(DAY,BSA.backup_finish_date,BS.backup_finish_date)			DiffDias
FROM
	backups BS
	CROSS APPLY
	(
		SELECT TOP 1
			* 
		FROM 
			backups BSA
		WHERE
			BSA.database_name = BS.database_name
			AND
			BSA.type = BS.type
			AND
			BSA.backup_finish_date <= BS.backup_finish_date
			AND
			BSA.backup_set_id != BS.backup_set_id
		ORDER BY
			BSA.backup_finish_date DESC
	) BSA
ORDER BY
	BS.database_name
	,BS.type
	,BS.backup_finish_date