/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		XE para coletar a atividade e erros em um banco específico.
		Use CTRL + SHIFT + M no SSMS para substituir o nome do banco.
		
		
*/



CREATE EVENT SESSION 
	[DatabaseActivityAndErrors] 
ON SERVER 

	-- Errors reported
	ADD EVENT 
		sqlserver.error_reported(
			
			ACTION(  package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id,sqlserver.sql_text
				)
			
			WHERE (
				[sqlserver].[equal_i_sql_unicode_string](
						[sqlserver].[database_name]
						,N'<DatabaseName,,The database where filter events>'
				)
			)
		)
		
	-- Prepared SQL event
		
	-- Procedure ends...
	,ADD EVENT sqlserver.prepare_sql(
			ACTION(	 package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id
					,sqlserver.sql_text
				)
			WHERE ( 
				[sqlserver].[equal_i_sql_unicode_string](
						[sqlserver].[database_name]
						,N'<DatabaseName,,The database where filter events>'
				)
			)
		)
		
	,ADD EVENT sqlserver.exec_prepared_sql(
			ACTION(	 package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id
					,sqlserver.sql_text
				)
			WHERE ( 
				[sqlserver].[equal_i_sql_unicode_string](
						[sqlserver].[database_name]
						,N'<DatabaseName,,The database where filter events>'
				)
			)
		)
		
	-- Procedure ends...
	,ADD EVENT sqlserver.module_end(
			ACTION(	 package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id
					,sqlserver.sql_text
				)
			WHERE ( 
				[sqlserver].[equal_i_sql_unicode_string](
						[sqlserver].[database_name]
						,N'<DatabaseName,,The database where filter events>'
				)
			)
		)

	-- Batch completed
	,ADD EVENT sqlserver.sql_batch_completed(
			ACTION(	 package0.event_sequence
					,sqlserver.client_app_name
					,sqlserver.client_hostname
					,sqlserver.database_name
					,sqlserver.server_principal_name
					,sqlserver.session_id
					,sqlserver.sql_text
				)
			WHERE ( 
				[sqlserver].[equal_i_sql_unicode_string](
						[sqlserver].[database_name]
						,N'<DatabaseName,,The database where filter events>'
				)
			)
		)
	
ADD TARGET 
	package0.ring_buffer 

WITH (
	 MAX_MEMORY 			= 4096 KB
	,EVENT_RETENTION_MODE	= ALLOW_SINGLE_EVENT_LOSS
	,MAX_DISPATCH_LATENCY	= 30 SECONDS
	,MAX_EVENT_SIZE			= 0 KB
	,MEMORY_PARTITION_MODE	= NONE 
	,TRACK_CAUSALITY		= OFF
	,STARTUP_STATE			= OFF
)
