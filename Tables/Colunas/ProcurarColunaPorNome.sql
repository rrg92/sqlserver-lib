/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Procura, em todos os bancos, por tabelas com colunas que contenham um texto específico.
		
*/

IF OBJECT_ID('tempdb..#Colunas') IS NOT NULL 
	DROP TABLE #Colunas;
GO

CREATE TABLE
	#Colunas(Banco sysname,Tabela sysname,Tipo varchar(50),Coluna sysname,TypeName sysname,Tamanho int)
GO

EXEC sp_MSforeachdb '
	USE [?];
	
	INSERT INTO
		#Colunas
	SELECT
		 ''?''	
		,o.name
		,o.type_desc
		,c.name
		,T.name
		,c.max_length
	FROM
					sys.columns c
		INNER JOIN	sys.objects o on o.object_id = c.object_id
		INNER JOIN sys.types T ON T.user_type_id = c.user_type_id
	WHERE
		c.name like ''%cnpj%'' --> AJUSTAR O NOME DA COLUNA PROCURADA AQUI
'
GO

SELECT * FROM #Colunas  
GO





