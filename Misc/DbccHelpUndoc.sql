/*#info 

	# Autor
		Rodrigo Ribeiro Gomes

	# Descrição
		Demonstrando traceflag 2588 para visualizar o help de comandos dbcc não documentados

*/
DBCC TRACEON(2588) WITH NO_INFOMSGS
GO

DBCC HELP('WRITEPAGE') WITH NO_INFOMSGS;
GO