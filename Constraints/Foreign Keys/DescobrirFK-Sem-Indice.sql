/*#info 
	
	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		 Lista todas as tabelas que não possui indice nas colunas referenciadas por outras. (do banco atual)
		 Supinha que voce tem uma tabela PAI e outra FILHA.
		 Você cria uma fk de FILHA -> PAI.
		 Se a coluna em PAI não tiver um índice, então, ela vai ser retornada nessa query. 

		 Esse script carece de algumas melhorias, por exemplo, quando são FKs compostas, ou duplicatas...
		 Mas, ele poe quebrar um galho na maioria dos ambientes e dá um bom norte!
*/
SELECT
	 Fkid = fk.object_id
	,FkName = fk.name
	,ParentTableId = fk.parent_object_id
	,ParentTableName = OBJECT_SCHEMA_NAME(fk.parent_object_id)+'.'+OBJECT_NAME(fk.parent_object_id)
	,ParentColName = c.name
	,ParentInexName = i.name
FROM
				sys.foreign_keys		fk
	INNER JOIN	sys.foreign_key_columns	fkc ON	fkc.constraint_object_id	= fk.object_id
	INNER JOIN	sys.columns				c	ON	c.column_id					= fkc.parent_column_id
											AND	c.object_id					= fkc.parent_object_id
	LEFT JOIN	(
							sys.index_columns		ic	
				INNER JOIN	sys.indexes				i	ON	i.index_id	= ic.index_id
														AND	i.object_id	= ic.object_id
				)	ON	ic.object_id	= c.object_id
					AND	ic.column_id	= fkc.parent_column_id
					AND ic.key_ordinal = 1
where
	i.name is null


