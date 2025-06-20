/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Capturar os checkpoint 
		Não me lembro que problema queria resolver ou se foi so pra uso acadêmico (provavemente foi apenas estudos ou lab mesmo)
		
		
*/

CREATE EVENT SESSION [TraceCheckpoints] ON SERVER 
	ADD EVENT sqlserver.checkpoint_begin(
		ACTION(
				package0.event_sequence
				,sqlserver.client_app_name
				,sqlserver.client_hostname
				,sqlserver.database_name
				,sqlserver.server_principal_name
				,sqlserver.session_id
				,sqlserver.sql_text
			)
		)
	,ADD EVENT sqlserver.checkpoint_end(
			ACTION(
				package0.event_sequence
				,sqlserver.client_app_name
				,sqlserver.client_hostname
				,sqlserver.database_name
				,sqlserver.server_principal_name
				,sqlserver.session_id
				,sqlserver.sql_text
			)
		)
	WITH (
		MAX_MEMORY=4096 KB
		,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
		,MAX_DISPATCH_LATENCY=30 SECONDS
		,MAX_EVENT_SIZE=0 KB
		,MEMORY_PARTITION_MODE=NONE
		,TRACK_CAUSALITY=OFF
		,STARTUP_STATE=OFF
	)
	GO

select * from sys.dm_xe_objects o where o.object_type = 'action'