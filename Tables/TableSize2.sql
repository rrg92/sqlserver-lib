/*#info

	# Autor
		Rodrigo Ribeiro Gomes 
		
	# Detalhes
		Lista o espaço ocupado por tabelas, incluindo consumo de index, LOB e compressão.  
		Útil para descobrir quais tabelas estão consumindo maior espaço.  
		O script considera todas as partições de uma tabela.
*/

SELECT
	ObjectName = schema_name(t.schema_id)+'.'+t.name
	,AU.*
	,'EXEC sp_spaceused '+QUOTENAME(schema_name(t.schema_id)+'.'+t.name,'''')+';'
FROM
	sys.tables t
CROSS APPLY
(
	SELECT
	   p.object_id
	   ,TotalRows = SUM(CASE WHEN p.index_id <= 1 AND au.type_desc = 'IN_ROW_DATA' THEN p.rows ELSE 0 END)
	   ,TotalMB = SUM(au.total_pages)/128.0
		,LobMB = ISNULL(SUM(CASE WHEN au.type_desc = 'LOB_DATA' THEN au.total_pages ELSE 0 END)/128.0,0)
	   ,RowOverMB = ISNULL(SUM(CASE WHEN au.type_desc = 'ROW_OVERFLOW_DATA' THEN au.total_pages ELSE 0 END)/128.0,0)
	   ,IndexSize = ISNULL(SUM(CASE WHEN p.index_id > 1 THEN au.total_pages ELSE 0 END)/128.0,0)
	   ,PageCompressionMB   = SUM(CASE WHEN p.data_compression_desc = 'PAGE' THEN au.total_pages ELSE 0 END)/128.0
	   ,RowCompressionMB    = SUM(CASE WHEN p.data_compression_desc = 'ROW' THEN au.total_pages ELSE 0 END)/128.0
	   ,TableCompressionMB = SUM(CASE WHEN p.data_compression_desc != 'NONE' AND p.index_id <= 1  THEN au.total_pages ELSE 0 END)/128.0
	   ,TableSize = SUM(CASE WHEN p.data_compression_desc != 'NONE' AND p.index_id <= 1  THEN au.total_pages ELSE 0 END)/128.0
	FROM
				   sys.allocation_units     au
				   JOIN
				   sys.partitions 			p  ON p.partition_id = au.container_id
	WHERE
				   p.object_id = t.object_id
	GROUP BY
				   p.object_id
) AU
ORDER BY
     TotalMB DESC
