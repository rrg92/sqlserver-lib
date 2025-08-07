/*#info

	# Autor
		Rodrigo Ribeiro Gomes 
		
	# Detalhes
		Lista o espaço ocupado por tabelas, incluindo consumo de index, LOB e compressão.  
		Útil para descobrir quais tabelas estão consumindo maior espaço.  
		O script considera todas as partições de uma tabela.
		
		Também, são incluídos os dados de Row Overflow e LOB.
		LOB são tipos para armazenar grande quantidades de dados. Eles são armazenados em estruturas separadas da linha na tabela.
		Row overflow é quando algumas colunas com varchar ultrapassam o limite da linha. Mais info aqui: https://learn.microsoft.com/en-us/sql/relational-databases/pages-and-extents-architecture-guide?view=sql-server-ver17#large-row-support
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
		 -- total de linhas estimado. Como faço join com a alloc units, preciso filtrar para não duplicar o total.
		,TotalRows = SUM(CASE WHEN p.index_id <= 1 AND au.type_desc = 'IN_ROW_DATA' THEN p.rows ELSE 0 END)
		
		-- tamanho total, somando toda a estrutura envolvida (indices, lobs, compressão etc.). Isso é tudo que sua tabela ocupa nos arquivos.
		-- as próximas colunas representam uma parte desse total
		,TotalMB = SUM(au.total_pages)/128.0
		
		-- tamanho somente de lobs (todos os indices)
		,LobMB = ISNULL(SUM(CASE WHEN au.type_desc = 'LOB_DATA' THEN au.total_pages ELSE 0 END)/128.0,0)
		
		-- tamanho somente de row overflow (todos os indices).
		,RowOverMB = ISNULL(SUM(CASE WHEN au.type_desc = 'ROW_OVERFLOW_DATA' THEN au.total_pages ELSE 0 END)/128.0,0)
		
		-- Tamanho de todos os índice (incluindo lobs e rowoverflow nesses índices)!
		,IndexSize = ISNULL(SUM(CASE WHEN p.index_id > 1 THEN au.total_pages ELSE 0 END)/128.0,0)
		
		-- Tamanho total da estruturas comprimidas.
		,PageCompressionMB   = SUM(CASE WHEN p.data_compression_desc = 'PAGE' THEN au.total_pages ELSE 0 END)/128.0
		,RowCompressionMB    = SUM(CASE WHEN p.data_compression_desc = 'ROW' THEN au.total_pages ELSE 0 END)/128.0
		
		-- total da tabela apenas (Sem os indices) comprimido
		,TableCompressionMB = SUM(CASE WHEN p.data_compression_desc != 'NONE' AND p.index_id <= 1  THEN au.total_pages ELSE 0 END)/128.0
		
		-- Tamanho total da tabela (sem índices), indepentende está comrpimido ou não. Se estiver comprimido, será igual a coluna TableCompressionMB
		,TableSize = SUM(CASE WHEN p.index_id <= 1  THEN au.total_pages ELSE 0 END)/128.0
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
