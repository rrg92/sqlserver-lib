/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Sessão XE para capturar atividade no t-log. Usei para estudos.
		
		
*/

CREATE EVENT SESSION LogActivity ON SERVER 
	ADD EVENT sqlserver.transaction_log (
		
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

-- ALTER EVENT SESSION [LogActivity] ON SERVER STATE = START
-- ALTER EVENT SESSION [LogActivity] ON SERVER STATE = STOP
-- DROP EVENT SESSION [LogActivity] ON server