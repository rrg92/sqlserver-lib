/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Alguma query que provavelmente usei para trazer informacoes dos índices que estavam sendo mais utilizados para leitura.
		
		
*/

USE master
GO

SELECT
	 ius.database_id
	,db_name(ius.database_id)							as NomeBD
	,ius.object_id										
	,object_name(ius.object_id,ius.database_id)			as NomeObj
	,ius.user_scans + ius.user_lookups + ius.user_seeks as Leituras
FROM
	sys.dm_db_index_usage_stats ius
WHERE
--	ius.database_id > 4
--	AND
--	ius.object_id > 100
--	AND
	ius.user_scans + ius.user_lookups + ius.user_seeks > 0
ORDER BY
	 Leituras DESC