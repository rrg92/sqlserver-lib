/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Checa se o database mirroring se está habilitado.
		Como não é toda versão que tem essa DMV, então, usamos query temporaria para rodar seguramente!
*/

IF OBJECT_ID('tempdb..#Mirroring') IS NOT NULL
	DROP TABLE #Mirroring;
CREATE TABLE #Mirroring(database_id int, mirroring_state smallint)

IF OBJECT_ID('sys.database_mirroring') IS NOT NULL
	EXEC('INSERT INTO #Mirroring SELECT database_id,mirroring_state FROM sys.database_mirroring')


SELECT 
	name
	,IsMergePublished = DATABASEPROPERTYEX(name,'IsMergePublished') 
	,M.mirroring_state
FROM 
	master..sysdatabases D
	LEFT JOIN
	#Mirroring M
		ON M.database_id = D.dbid
WHERE
	M.mirroring_state IS NOT NULL