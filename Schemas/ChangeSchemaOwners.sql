/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
	
	# Descrição 
		Script simpels para gerar o comando de ALTER OWNER dos schemas!

*/

USE master
GO

IF OBJECT_ID('tempdb..#SchemasOwners') IS NOT NULL
	DROP TABLE #SchemasOwners;
	
--> Query apenas para gerar a tabela temporaria com a estrutura abaixo.
SELECT
	 S.name		as NomeS
	,P.name		as NomeP
	,DB_NAME()	as Banco
INTO
	#SchemasOwners
FROM
	sys.schemas S 
	JOIN
	sys.database_principals P
		ON P.principal_id = S.principal_id 
WHERE
	1 = 2

EXECUTE sp_MSforeachdb '
USE ?;

INSERT INTO
	#SchemasOwners
SELECT
	 S.name
	,P.name
	,DB_NAME()
FROM
	sys.schemas S 
	JOIN
	sys.database_principals P
		ON P.principal_id = S.principal_id 
WHERE
	P.principal_id > 4
	AND
	P.is_fixed_role = 1
'

SELECT 
	'USE '+SO.Banco+';ALTER AUTHORIZATION ON SCHEMA::'+QUOTENAME(SO.NomeS)+' TO '+QUOTENAME(SO.NomeS)+';' 
FROM 
	#SchemasOwners SO
WHERE
	SO.NomeP <> SO.NomeS;
	
