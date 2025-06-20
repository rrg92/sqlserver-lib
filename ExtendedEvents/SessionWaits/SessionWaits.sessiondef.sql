/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		XE para capturar os waits de uma sessão .
		Criado numa época que ainda não existia a maravilhosa sys.dm_exec_sessions_wait_stats
		Era assim que tínhamos que fazer (2008+).
		
		
*/

CREATE EVENT SESSION [SessionWaitsInfo] ON SERVER 
	ADD EVENT sqlos.wait_info (
		
		ACTION (
			sqlserver.session_id
		)

		WHERE (
			-- Filtering... Can use "session_id" (2008)
			package0.equal_binary_data(sqlserver.context_info, 0xDeadC0de )
		)
	)

	ADD TARGET package0.ring_buffer(
		SET max_memory=(4096)
	)
WITH (
	MAX_DISPATCH_LATENCY=1 SECONDS
)
GO

-- ALTER EVENT SESSION [SessionWaitsInfo] ON SERVER STATE = START
-- ALTER EVENT SESSION [SessionWaitsInfo] ON SERVER STATE = STOP
-- DROP EVENT SESSION [sessionWaitsInfo] ON server