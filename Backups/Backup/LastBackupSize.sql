/*#info 
	
	# Author 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Lista o tamanho do último backup de cada banco (de cada tipo).
		Ultimo para rápida conferencia de tamanho

*/

SELECT
	BS.database_name
	,BS.type
	,CompressedSize = sum(bs.compressed_backup_size/1024./1024/1024) -- em GB
	,NormalSize = sum(bs.backup_size/1024./1024/1024) -- em GB
FROM
	msdb..backupset BS
WHERE
	bs.type IN ('D')
	and
	is_copy_only = 0
	AND
	BS.backup_set_id = ( SELECT MAX(BSi.backup_set_id) from msdb..backupset BSI where BSI.database_name = bs.database_name and bsi.type = bs.type and bsi.is_copy_only = 0 )
group by
	-- 2 agrupamentos = total e por banco/tipo
	grouping sets (
		(),(
			BS.database_name
			,BS.type)
	)