/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Esse script foi uma tentativa inicial de tentar listar índices duplicados reais.
		Muitos scritps que eu encontro, apenas focam em listar os duplicados exatamente com a mesma estrutura de colunas e mesma ordem.
		Mas, existem outros pontos de duplicação, mesmo que não sejam iguais.
		Por exemplo, um índice na coluna A que tem no include a coluna C1,C2 e o outro índice na coluna A que tem as colunas C1,C2 e C3. 
		Outro ponto que outros scripts deixam de consideraré a ordenação. Um índice na coluna A DESC,B ASC é diferente de um indice A ASC,B ASC (podem atender conjunto de queries diferentes), então não podemos considerá-los como iguais em todos o caso.
		
		Eu comecei esse script e cheguei a usar em alguns casos, mas ainda preciosa de tapas e revisões.
		No futuro, posso atualizá-lo.
		
		
*/

IF OBJECT_ID('tempdb..#DupIndex') IS NOT NULL
	DROP TABLE #DupIndex

SELECT
	*
	,FullIndexChecksum = CHECKSUM(I.FullTableName,I.IndexType,I.KeyIndexCol,I.IncludedCols)
	,KeyIndexChecksum = CHECKSUM(I.FullTableName,I.IndexType,I.KeyIndexCol)
	,FullDupRn = ROW_NUMBER() OVER( PARTITION BY I.FullTableName,I.IndexType,I.KeyIndexCol,I.IncludedCols ORDER BY I.IndexName )
	,DupKeyRank = DENSE_RANK() OVER( PARTITION BY I.FullTableName,I.IndexType,I.KeyIndexCol ORDER BY  IncludedCount DESC )
INTO
		#DupIndex
FROM
(
	SELECT
		 ObjectId  = T.object_id
		,TableName = T.name
		,FullTableName = S.name+'.'+T.name
		,IndexName = I.name
		,IndexType = I.type_desc
		,KeyIndexCol = STUFF(
				(SELECT	
				','+IIF(IC.is_included_column = 1,'INC:','')+C.name+' '+IIF(IC.is_descending_key = 1,'DESC','ASC') as 'text()'
			FROM
				sys.index_columns IC
				JOIN
				sys.columns C
					ON C.object_id	= IC.object_id
					AND C.column_id = IC.column_id
			WHERE
				IC.object_id = I.object_id
				AND
				IC.index_id = I.index_id
				AND
				IC.is_included_column = 0
			ORDER BY
				IC.is_included_column
				,IC.key_ordinal
			FOR XML PATH('')
			),1,1,''
		)
		,IncludedCols = STUFF(
				(SELECT	
				','+IIF(IC.is_included_column = 1,'INC:','')+C.name 'text()'
			FROM
				sys.index_columns IC
				JOIN
				sys.columns C
					ON C.object_id	= IC.object_id
					AND C.column_id = IC.column_id
			WHERE
				IC.object_id = I.object_id
				AND
				IC.index_id = I.index_id
				AND
				IC.is_included_column = 1
			ORDER BY
				IC.is_included_column
				,IC.key_ordinal
				,C.name
			FOR XML PATH('')
			),1,1,''
		)
		,IncludedCount = (
			SELECT
				COUNT(*)
			FROM
				sys.index_columns IC
			WHERE
				IC.object_id = I.object_id
				AND
				IC.index_id = I.index_id
				AND
				IC.is_included_column = 1
		 )
		,IndexImportance = (
			SELECT
				1.0/(SUM(SamePosition)*1./COUNT(*))
			FROM
				sys.index_columns IC
				JOIN
				sys.columns C
					ON C.object_id	= IC.object_id
					AND C.column_id = IC.column_id
				CROSS APPLY (
					SELECT	
						SamePosition = COUNT(*) 
					FROM
						sys.index_columns IC2
					WHERE
						IC2.object_id = IC.object_id
						AND
						IC2.column_id = C.column_id
						AND
						IC2.is_included_column = 0
						AND
						IC2.key_ordinal = IC.key_ordinal
				) IMP
			WHERE
				IC.object_id = I.object_id
				AND
				IC.index_id = I.index_id
				AND
				IC.is_included_column = 0
		 )
	FROM
		sys.indexes I
		JOIN
		sys.tables T
			ON T.object_id = I.object_id
		JOIN
		sys.schemas S
			ON S.schema_id = T.schema_id
	WHERE
		I.index_id >= 1
		AND
		I.is_disabled = 0
) I
ORDER BY
	I.FullTableName
	,I.IndexName

-- duplicados
SELECT
	*
FROM
	#DupIndex 
ORDER BY
	FullTableName,KeyIndexCol,KeyIndexChecksum,DupKeyRank