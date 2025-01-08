/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Este script foi criado para rodar no SSMS, usando o SQLCMD mode.
		
		Com AlwaysON, é bem comum você querer consultar as várias réplicas ao mesmo tempo.
		Tem várias maneiras de fazer isso: Você poderia criar um CMS, usar powershell, etc.  
		
		
		Uma delas, é usar o SQLCMD mode do Management Studio.
		Nesse modo, você tem algumas sintaxes especiais no editor que pode, no meio do script, conectar em outro servidor!
		Neste caso, é bem útil quando você quer executar uma mesma query em diferentes instância e comparar o resultado ali na mesma tela.
		Isso fica bem produtivo!
		
		Para habilitar o SQLCMD Mode no SSMS, vá em Query -> SQLCMD Mode (clica e o ícone vai ficar destacado, indicando que ativou).
		O comando ":connect" é disponibilizado via SQLCMD mode. Com ele você pode se conectar em uma instância específica.
		
		Note que para funcionar, a máquina onde você está rodando o SSMS deve conseguir chegar na instância que está tentando conectar.
		Se, por exemplo, está dentro do servidor, então ele tem que ter permissão.
		
		MAis sobre o SQLCMD Mode: https://learn.microsoft.com/en-us/sql/tools/sqlcmd/edit-sqlcmd-scripts-query-editor?view=sql-server-ver16
		
		## Sobre o script
		
		Este script traz informações de cada banco de dados de cada AG em cada replica.
		Se você rodar na primária, ele vai ter 1 linha para cada base de cada AG de cada réplica.
		Se você rodar na secundária, vai ter 1 linha para cada base de cada AG associado este secundário.
		
		A coluna is_local indica se a linha é referente a instãncia onde você está executando o script.
		quando 1, então é a linha correspondente a instância atual.
		
		
		Sobre a DMV:
		https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-hadr-database-replica-states-transact-sql
		
	
		No caso abaixo, a última vez que usei o script era pra analisar o sincronismo com a secundária.
		Eu queria entender a diferença de dados entre o primário e o secundário.
		
		Na primaira, filtrei is_local = 0, pois queria as linhas com os dados de sincronização com a secundária.
		Na secundária, filtrei is_local = 1, pois queria as linhas com os dados da própria secundária.
		
		
		Geralmente, quando está tudo ok na comunicação, os valores são bem próximos.
		Se estiver muito discrepante, pode indicar algum problema na comunicação (lentidão da rede, probs do sql, bugs, etc.)
*/


:connect SERVER\INSTANCIA1 -- No meu caso, era a primaria
SELECT @@servername,D.name,d.log_reuse_wait_desc,synchronization_state_desc,log_send_rate,redo_queue_size,redo_rate,last_commit_time,last_hardened_time,last_sent_time,last_sent_lsn,last_redone_time 
,last_received_time
fROM sys.dm_hadr_database_replica_states RS
INNER JOIN sys.databases D on D.database_id = RS.database_id
where is_local = 0
 order by D.name
 GO


:connect SERVER\INSTANCIA2 -- No meu caso, era a secundária
SELECT @@servername,D.name,d.log_reuse_wait_desc,synchronization_state_desc,log_send_rate,redo_queue_size,redo_rate,last_commit_time,last_hardened_time,last_sent_time,last_sent_lsn,last_redone_time 
,last_received_time
fROM sys.dm_hadr_database_replica_states RS
INNER JOIN sys.databases D on D.database_id = RS.database_id
where is_local = 1
 order by D.name
 GO


 