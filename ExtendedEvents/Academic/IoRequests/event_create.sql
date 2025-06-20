/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Capturar as requisições de I/O feitas pelo SQL.  
		Pega tanto o início (_Requested), quando a conclusão (_completed). 
		Eu acho que só usei isso para demonstrações (não lembro de ter usado em produção, mas pode ter sido).
		Note que deixei um filtro de session_id, filtrando aepnas de uma sessão em específico;
		
		
*/

-- alter event session [IoRequests] on server state = start
-- alter event session [IoRequests] on server state = stop

CREATE EVENT SESSION 
	[IoRequests] 
ON  SERVER 
	ADD EVENT sqlos.async_io_requested(

			ACTION(
				sqlserver.session_id
				,sqlserver.client_app_name
				,sqlserver.database_name
				,sqlserver.server_principal_name
				,package0.event_sequence
			)
			WHERE (
				[package0].[equal_uint64]([sqlserver].[session_id],(51))
				)
		)
	,ADD EVENT sqlos.async_io_completed(

			ACTION(
				sqlserver.session_id
				,sqlserver.client_app_name
				,sqlserver.database_name
				,sqlserver.server_principal_name
				,package0.event_sequence
			)
			WHERE (
				[package0].[equal_uint64]([sqlserver].[session_id],(51))
				)
		)
	
ADD TARGET
	package0.ring_buffer

WITH (
	MAX_MEMORY=4096 KB
	,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
	,MAX_DISPATCH_LATENCY=30 SECONDS
	,MAX_EVENT_SIZE=0 KB
	,MEMORY_PARTITION_MODE=NONE
	,TRACK_CAUSALITY=OFF
	,STARTUP_STATE=OFF
)