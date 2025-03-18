/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Uma das primeiras versões que criei para obter info de backup


*/

SELECT
	B.Data
	,COUNT(B.backup_set_id)
	,COUNT(CASE WHEN B.type = 'D' THEN B.backup_set_id END) as QtdFull
	,COUNT(CASE WHEN B.type = 'I' THEN B.backup_set_id END) as QtdDiff
	,COUNT(CASE WHEN B.type = 'L' THEN B.backup_set_id END) as QtdLog
	,SUM(CASE WHEN B.type = 'D' THEN B.compressed_backup_size END)/1024/1024 as TamFull
	,SUM(CASE WHEN B.type = 'I' THEN B.compressed_backup_size END)/1024/1024 as TamDiff
	,SUM(CASE WHEN B.type = 'L' THEN B.compressed_backup_size END)/1024/1024 as TamLog
FROM
	(
		SELECT
			--DATEADD(DD,DATEDIFF(DD,'19000101',backup_finish_date),'19000101') as Data
			CONVERT(date,backup_finish_date) as Data
			,BS.*
		FROM
			msdb.dbo.backupset BS
		WHERE
			is_copy_only = 0
			AND
			BS.backup_finish_date >= '20150201' --> Ajustar a data aqui
	) B
GROUP BY	
	Data
ORDER BY	
	Data

	