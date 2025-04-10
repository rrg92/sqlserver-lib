/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Esse script já me ajudou muitas e muitas vezes para achar as dependências de um objet, como view, procedure, etc.
		Você passa o nome da view, e então ele usa a DMV sys.sql_expression_dependencies recursivamente para achar todas as dependências.
		O legal, é que ele acha as dependências em outros bancos, então é bem útil.
		
		As colunas retornadas são:
			referenced_id 		= object_id da dependencia 
			ReferencedObject	= nome do objeto referenciado (sem o esquema)
			type_desc 			= Tipo do objeto dependente 
			RefLevel 			= O nível de dependência. 1 é dependêcnia direta (está direto no código do objeto que você colocou).
									2, ele encontrou em um dos obejtos de nível 1
									3, el encontrou em um dos objetos de nível 2 e por aí vai!
			RefChain 			= Uma representação visual da dependência, partindo do objeto que você passou até este atual.
									Com isso você consegue ver todos os objetos referenciados até chegar neste da linha respectiva.
		
*/


;WITH Depends AS (
	SELECT
		E.referencing_id 
		,E.referenced_id
		,E.referenced_database_name
		,ReferencedObject = CONVERT(nvarchar(1000),ISNULL(E.referenced_server_name+'.','')+ISNULL(E.referenced_database_name+'.','')+ISNULL(E.referenced_schema_name+'.','')+ISNULL(E.referenced_entity_name,''))
		,RefLevel = CONVERT(bigint,1) 
		,RefChain = CONVERT(nvarchar(max), OBJECT_NAME(E.referencing_id)+'->'+E.referenced_entity_name )
	FROM
		sys.sql_expression_dependencies E
	WHERE
		E.referencing_id = OBJECT_ID('schema.NomeTabela')


	UNION ALL

	SELECT
		E.referencing_id 
		,E.referenced_id
		,E.referenced_database_name
		,ReferencedObject = CONVERT(nvarchar(1000),ISNULL(E.referenced_server_name+'.','')+ISNULL(E.referenced_database_name+'.','')+ISNULL(E.referenced_schema_name+'.','')+ISNULL(E.referenced_entity_name,''))	
		,RefLevel = CONVERT(bigint,D.RefLevel + 1)
		,RefChain = CONVERT(nvarchar(max), D.RefChain+'->'+E.referenced_entity_name )
	FROM
		Depends D
		INNER JOIN
		sys.sql_expression_dependencies E
			ON E.referencing_id = D.referenced_id
	WHERE
		E.referenced_minor_id = 0

)
SELECT
	D.referenced_id
	,D.ReferencedObject
	,O.type_desc
	,D.RefLevel
	,D.RefChain
FROM
	Depends D
	LEFT JOIN
	sys.objects O
		ON (D.referenced_database_name IS NULL OR D.referenced_database_name = DB_NAME())
		AND D.referenced_id = O.object_id
ORDER BY
	D.RefLevel
