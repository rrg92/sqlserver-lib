/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Comandos DBCC para ver ou setar dumptrigger.
		Mais info: https://techcommunity.microsoft.com/blog/sqlserversupport/how-do-i-determine-which-dump-triggers-are-enabled/315740
		e https://techcommunity.microsoft.com/blog/sqlserversupport/how-it-works-controlling-sql-server-memory-dumps/315875

*/

-- ver as triggers habilitadas
dbcc traceon(3604)
DBCC DUMPTRIGGER('display')

-- Set trigger para um erro especifico
-- DBCC DUMPTRIGGER('set',CodigoErro)

-- remover trigger
-- DBCC DUMPTRIGGER('clear',CodigoErro)