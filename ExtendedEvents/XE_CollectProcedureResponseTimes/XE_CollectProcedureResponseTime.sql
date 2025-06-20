/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Capturar todas as procedurem que concluem a execução.
		ATENÇÃO: Isso pode impactar a performance, cuidado.
		
		
*/


IF EXISTS(SELECT * FROM sys.server_event_sessions SES WHERE SES.name = 'XE_CollectProcedureResponseTime')
	EXEC('DROP EVENT SESSION XE_CollectProcedureResponseTime ON SERVER');

CREATE EVENT SESSION XE_CollectProcedureResponseTime ON SERVER
	ADD EVENT sqlserver.module_end
				(
					WHERE
						package0.equal_ansi_string(object_type,'P')
				)
	ADD TARGET package0.ring_buffer (
		SET max_memory = 10240
	)

WITH (
	MAX_MEMORY = 4MB
	,EVENT_RETENTION_MODE = ALLOW_MULTIPLE_EVENT_LOSS
	,MAX_DISPATCH_LATENCY = 30 SECONDS
	,MAX_EVENT_SIZE = 2MB
	,MEMORY_PARTITION_MODE = PER_CPU
	,STARTUP_STATE = OFF
)




/*
HELP


SELECT * FROM sys.dm_xe_packages where guid = '60AA9FBF-673B-4553-B7ED-71DCA7F5E972'
SELECT * FROM sys.dm_xe_objects WHERE object_type = 'target' pr name = 'asynchronous_file_target'
SELECT * FROM sys.dm_xe_object_columns WHERE object_name = 'asynchronous_file_target'


*/