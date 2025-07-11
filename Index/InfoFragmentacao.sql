/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Alguma query que usei quando comecei a estudar sobre fragmentação.
		Nenhum efeito prático em produção.
		
		
*/

/**
	avg_fragmentation_int_percent --> Percentual de páginas que estão fora de ordem.
**/

SELECT
	 IPS.index_type_desc
	,OBJECT_NAME(IPS.object_id,IPS.database_id)				AS Tabela
	,IPS.avg_fragmentation_in_percent
	,IPS.fragment_count
	,IPS.avg_fragment_size_in_pages
	,IPS.page_count
	,IPS.index_level
	,IPS.page_count * IPS.avg_fragmentation_in_percent/100. AS QtdPaginasForaOrdem
FROM
	sys.dm_db_index_physical_stats
	(DB_ID('TesteFrag')
	,NULL--OBJECT_ID('TesteFrag..TabelaTeste')
	,NULL--1
	,NULL
	,'DETAILED') IPS
WHERE
	IPS.object_id IN (OBJECT_ID('TesteFrag..TabelaTeste'))
	--AND
	--IPS.index_id = 1
ORDER BY
	Tabela
	
	
-- 
SELECT
	 IUS.database_id
	,IUS.object_id
	,IUS.index_id
	,IUS.user_updates
	,IUS.last_user_update
FROM
	sys.dm_db_index_usage_stats IUS
	
SELECT
	*
FROM
	sys.dm_os_performance_counters PC
WHERE
		PC.object_name	= 'SQLServer:Access Methods'
	AND PC.counter_name = 'Page Splits/sec'

