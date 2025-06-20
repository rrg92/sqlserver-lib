/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		XE para capturar várias evetos de atividade na instância.
		CUIDADO: não tem filtros... Sem filtros, pode impactar no ambiente.
		
		
*/

CREATE EVENT SESSION [DBA_ActivityTrace] ON SERVER 
	ADD EVENT sqlserver.exec_prepared_sql(
			ACTION(
					package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.client_pid
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id
					,sqlserver.sql_text
					,sqlserver.transaction_id
					,sqlserver.username
				)
		)

	,ADD EVENT sqlserver.rpc_completed(
		
			ACTION(
					package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.client_pid
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id
					,sqlserver.sql_text
					,sqlserver.transaction_id
					,sqlserver.username
				)
		
		)

	,ADD EVENT sqlserver.sql_batch_completed(
			ACTION(
					package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.client_pid
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id
					,sqlserver.sql_text
					,sqlserver.transaction_id
					,sqlserver.username
				)
		 )
		 
	ADD TARGET package0.event_file (
			SET filename=N'F:\Traces\DBA_ActivityTrace.xel'
		)
	
	WITH (
		MAX_MEMORY=102400 KB
		,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
		,MAX_DISPATCH_LATENCY=1 SECONDS
		,MAX_EVENT_SIZE=0 KB
		,MEMORY_PARTITION_MODE=NONE
		,TRACK_CAUSALITY=OFF
		,STARTUP_STATE=OFF
	)

