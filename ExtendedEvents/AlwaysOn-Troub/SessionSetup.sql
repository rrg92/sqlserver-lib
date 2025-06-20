/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Capturar eventos Extended Events para debugar o AlwaysON.
		Substituir o nome do banco DbTest 
		
		
*/

CREATE EVENT SESSION [AlwaysOn-Troub] ON SERVER 
ADD EVENT sqlos.async_io_completed(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlos.async_io_requested(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlos.wait_completed(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlos.wait_info(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest') AND [wait_type]<>(1146))),
ADD EVENT sqlserver.checkpoint_begin(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlserver.checkpoint_end(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlserver.hadr_db_manager_redo(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlserver.lock_redo_blocked(SET collect_database_name=(1),collect_resource_description=(1)
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlserver.lock_redo_unblocked(SET collect_database_name=(1),collect_resource_description=(1)
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlserver.redo_caught_up(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest'))),
ADD EVENT sqlserver.redo_single_record(
    ACTION(package0.event_sequence,package0.last_error,sqlos.scheduler_id,sqlos.system_thread_id,sqlos.task_address,sqlserver.database_name,sqlserver.session_id)
    WHERE ([sqlserver].[equal_i_sql_unicode_string]([sqlserver].[database_name],N'DbTest')))
ADD TARGET package0.ring_buffer(SET max_events_limit=(10000),max_memory=(51200))
WITH (MAX_MEMORY=512000 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=2 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

