/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Um dos primeiros scrips para info de backup


*/

SELECT 
	 DiaBackup
	,database_name
	,sum(backup_size)
FROM 
	(select *,DATEADD(DD,DATEDIFF(DD,'19000101',backup_finish_date),'19000101') Diabackup from msdb.dbo.backupset) D
WHERE
	type = 'D'
	and
	backup_finish_date >= '20150501'
group by
	 DiaBackup
	,database_name
order by
	database_name,DiaBackup desc

option(maxdop 1)