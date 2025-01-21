/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Retornar tabelas cuja primeira coluna é texto (tem collation associado)
*/
SELECT
	T.name
	,C.name
	,C.collation_name
	,L.NumRows
	,IC.*
FROM
	sys.columns C
	INNER JOIN
	sys.tables T
		ON T.object_id = C.object_id
	INNER JOIN (
		SELECT 
			P.object_id
			,SUM(P.rows) as NumRows
		FROM 
			sys.partitions P 
		WHERE
			P.index_id IN (1,0)
		GROUP BY 
			P.object_id
	) L
		ON L.object_id = T.object_id
	INNER JOIN
	sys.index_columns IC
		ON IC.object_id = T.object_id
		AND IC.column_id = C.column_id
WHERE
	collation_name IS NOT NULL
	AND
	IC.key_ordinal = 1
ORDER BY
	L.NumRows DESC

