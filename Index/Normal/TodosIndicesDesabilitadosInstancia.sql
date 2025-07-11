/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		TRaz todos os índices desabilitados na instância.
		
		
*/

CREATE TABLE #Desabilitados( Banco sysname, Tabela sysname, Indice sysname );

sp_MSforeachdb '
USE ?;

INSERT INTO
	#Desabilitados
SELECT
	 db_name()
	,object_name( i.object_id  )
	,i.name
FROM
	sys.indexes i
WHERE
	is_disabled = 1
'


SELECT * FROM #Desabilitados;