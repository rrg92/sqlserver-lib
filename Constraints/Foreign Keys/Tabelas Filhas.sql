/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Lista todas as tabelas filhas de uma tabela específica.
		Traz a tabela e as colunas envolvidas
*/
SELECT
	OBJECT_NAME(parent_object_id) as Tabela
	,STUFF(T.colunas,1,1,null) as [Coluna(s)]
FROM
	sys.foreign_keys FK
	OUTER APPLY
	(
		SELECT
			','+C.name
		FROM
			sys.foreign_key_columns FKC
			inner join
			sys.columns C
				ON C.object_id = FKC.parent_object_id
				AND C.column_id = fkc.parent_column_id
		WHERE
			FKC.constraint_object_id = FK.object_id
		FOR XML PATH('')
	) T(colunas)
WHERE
	FK.referenced_object_id = OBJECT_ID('dbo.pai') -- Aqui pode colocar o nome da tabela
	
	--select * from 	sys.foreign_key_columns