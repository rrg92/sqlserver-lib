/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Coletar XE com info de waits (intenro e externo) de uma sessão
		
		
*/


/*
select * from sys.dm_xe_packages
select * from sys.dm_xe_objects where name+object_type like '%wait_info%';
select * from sys.dm_xe_object_columns where name+object_name like '%wait_info%';
ALTER EVENT SESSION XE_PerfomanceDebug ON SERVER STATE = STOP
DROP EVENT SESSION XE_PerfomanceDebug on server
*/

CREATE EVENT SESSION XE_PerfomanceDebug ON SERVER
	ADD EVENT sqlos.wait_info (
		ACTION (
			sqlserver.session_id
		)

		WHERE
				sqlserver.session_id = 80
	)
	,ADD EVENT sqlos.wait_info_external (
		ACTION (
			sqlserver.session_id
		)

		WHERE
				sqlserver.session_id = 80
	)

	ADD TARGET package0.asynchronous_file_target (
		SET filename = 'C:\temp\waitsperformance'
			,max_file_size = 10
	)

WITH (
	MAX_MEMORY = 4MB
	,EVENT_RETENTION_MODE = ALLOW_MULTIPLE_EVENT_LOSS 
	,MAX_DISPATCH_LATENCY  = 1 SECONDS
	,STARTUP_STATE = OFF
)