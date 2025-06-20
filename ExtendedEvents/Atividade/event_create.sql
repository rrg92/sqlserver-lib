/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Capturar eventos Extended Events com todos os comandos que concluem no banco. 
		ATENÇÃO: Isso pode impactar a performance de algumas queries. USar com muita cautela e geralmente por alguns poucos segundos para rápida coleta.
		
		
*/


-- alter event session [ServerWork] on server state = start
-- alter event session [ServerWork] on server state = stop

CREATE EVENT SESSION 
	[ServerWork] 
ON 
	SERVER 
ADD EVENT sqlserver.sql_batch_completed(

		ACTION(
			sqlserver.session_id
			,sqlserver.client_app_name
			,sqlserver.context_info
			,sqlserver.database_name
			,sqlserver.server_principal_name
			,package0.debug_break
		)
		--WHERE (
		--		[package0].[equal_uint64]([sqlserver].[session_id],(51))
		--	)
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