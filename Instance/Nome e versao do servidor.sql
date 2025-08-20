/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Alguns comandos pra obter info do servidor


*/

sp_server_info 

SELECT SERVERPROPERTY('productversion'), SERVERPROPERTY ('productlevel'), SERVERPROPERTY ('edition')

print @@servername
print @@version

select * from sys.fulltext_languages