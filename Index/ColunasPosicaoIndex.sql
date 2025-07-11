/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Retorna a lista de tabelas e colunas e os índices cujo essa coluna estão em uma posição específica do indice.
		Por exemplo, com o valor padrão do filtro key_ordinal, ele retorna apenas os índices em que a coluna é a primeira posição no índice.
		
		Note que a função STRING_AGG só existe no 2019 em diante.
		Se você precisar executar em uma versão anterior, pode usar outras técnicas, com FOR XML, por exemplo.
		
*/
SELECT
	t.name
	,c.name
	,I.Indexes
FROM
	sys.tables t
	join
	sys.columns c
		on c.object_id = t.object_id
	OUTER APPLY (
		SELECT
			Indexes = STRING_AGG(i.name,',')
		FROM
			sys.index_columns IC
			join
			sys.indexes i
				on i.object_id = ic.object_id
				and i.index_id = ic.index_id
		WHERE
			IC.object_id = C.object_id
			and
			IC.key_ordinal = 1
			AND
			IC.object_id = C.object_id
			AND
			IC.column_id = C.column_id
	) I


	 