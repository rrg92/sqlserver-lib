/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Capturar atividades de um módulo específico.
		Um módulo é uma procedure, trigger ou função.
		Se estiver no SSMS, use CTRL + SHIFT + M para substituir os placeholders com o nome do modulo e caminho onde logar.
		
		
*/

-- DROP EVENT SESSION [DBA_ModuleTrace] ON SERVER 

CREATE EVENT SESSION [DBA_ModuleTrace] ON SERVER 
	ADD EVENT sqlserver.module_end(
		SET collect_statement=(1)
		ACTION(
			sqlos.cpu_id
			,sqlos.scheduler_id
			,sqlos.system_thread_id
			,sqlos.worker_address
			,sqlserver.client_app_name
			,sqlserver.client_pid
			,sqlserver.database_name
			,sqlserver.nt_username
			,sqlserver.query_hash
			,sqlserver.query_plan_hash
			,sqlserver.session_id
			,sqlserver.sql_text
		)
		WHERE
			object_name = N'<OBJECT_NAME,,>'
	)
	
	,ADD EVENT sqlserver.module_start(
		SET collect_statement=(1)
		ACTION(
			sqlos.cpu_id
			,sqlos.scheduler_id
			,sqlos.system_thread_id
			,sqlos.worker_address
			,sqlserver.client_app_name
			,sqlserver.client_pid
			,sqlserver.database_name
			,sqlserver.nt_username
			,sqlserver.query_hash
			,sqlserver.query_plan_hash
			,sqlserver.session_id
			,sqlserver.sql_text
		)
		WHERE
			object_name = N'<OBJECT_NAME,,>'
	)

	,ADD EVENT sqlserver.sp_statement_completed(
		SET collect_object_name=(1)
			,collect_statement=(1)
    
		ACTION(
			sqlos.cpu_id
			,sqlos.scheduler_id
			,sqlos.system_thread_id
			,sqlos.worker_address
			,sqlserver.client_app_name
			,sqlserver.client_pid
			,sqlserver.database_name
			,sqlserver.nt_username
			,sqlserver.query_hash
			,sqlserver.query_plan_hash
			,sqlserver.session_id
			,sqlserver.sql_text
		
		)
		WHERE
			[object_name] = N'<OBJECT_NAME,,>'

	)
	,ADD EVENT sqlserver.sp_statement_starting(
			SET collect_object_name=(1)
			ACTION(
				sqlos.cpu_id
				,sqlos.scheduler_id
				,sqlos.system_thread_id
				,sqlos.worker_address
				,sqlserver.client_app_name
				,sqlserver.client_pid
				,sqlserver.database_name
				,sqlserver.nt_username
				,sqlserver.query_hash
				,sqlserver.query_plan_hash
				,sqlserver.session_id
				,sqlserver.sql_text
			)
			
			WHERE
				[object_name] = N'<OBJECT_NAME,,>'

		)
		
	ADD TARGET package0.event_file(
		SET filename=N'<DIRECTORY,,>\DBA_ModuleTrace'
			,max_file_size= 500
			,MAX_ROLLOVER_FILES = 5
		)
		
	WITH (
		MAX_MEMORY				= 10 MB
		,EVENT_RETENTION_MODE	= ALLOW_SINGLE_EVENT_LOSS
		,MAX_DISPATCH_LATENCY	= 1 SECONDS
		,MAX_EVENT_SIZE			= 0 KB
		,MEMORY_PARTITION_MODE	= NONE
		,TRACK_CAUSALITY		= OFF
		,STARTUP_STATE			= OFF
	)
GO


