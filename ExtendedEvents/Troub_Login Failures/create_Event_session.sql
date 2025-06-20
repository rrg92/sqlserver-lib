/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		XE para capturar erros de login (através do range do código do erro).
		
		
*/

CREATE EVENT SESSION [Troub: Login Failures] 
ON SERVER
ADD EVENT sqlserver.error_reported
(
	ACTION (sqlserver.database_id, 
			sqlserver.sql_text, 
			sqlserver.database_context, 
			sqlserver.client_app_name, 
			sqlserver.client_pid,
			sqlserver.client_hostname, 
			sqlserver.nt_username,
			sqlserver.session_nt_username, 
			sqlserver.username, 
			sqlserver.session_id, 
			package0.collect_system_time)
WHERE
		error > 18450 and error < 18489
)
--ADD TARGET
--		package0.asynchronous_file_target (SET FILENAME = 'C:\Temp\XE_LOGIN_FAILURE.xel', metadatafile = 'C:\Temp\XE_LOGIN_FAILURE.xem')
	ADD
		TARGET
			package0.ring_buffer
			(
				SET 
					max_memory = 1000

			)

--ALTER EVENT SESSION [Troub: Login Failures] ON SERVER STATE = START;
--GO

---- STEP 4: Stop the XEvent Session
--ALTER EVENT SESSION [Troub: Login Failures] ON SERVER STATE = STOP;

---- STEP 5: Drop the XEvent Session
--DROP EVENT SESSION [Troub: Login Failures] ON SERVER;