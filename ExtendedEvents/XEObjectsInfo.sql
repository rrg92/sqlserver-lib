/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Query simples para consultar coluans do XE. 
		Usei muito quando nem existia a UI no SSMS para criar XE...
		Hoje em dia, uso mais a UI, mas, deixo aqui para quem ainda prefere no script direto (ou não tem a opção da UI fácil)
		
		
*/

SELECT
	P.name+'.'+O.name as FullName
	,O.object_type
	,O.description
	,OC.name			as colname
	,OC.description		as coldesc
	,OC.type_name		as coltype
FROM
	sys.dm_xe_objects O
	INNER JOIN
	sys.dm_xe_packages P
		ON P.guid = O.package_guid
	LEFT JOIN
	sys.dm_xe_object_columns OC
		ON OC.object_name = O.name
WHERE
	O.name LIKE '%plan%'
	--OR
	--O.name like '%ring_buffer%'
ORDER BY
	O.name


-- sqlserver.sql_statement_completed, sqlserver.sp_statement_completed, sqlserver.rpc_completed