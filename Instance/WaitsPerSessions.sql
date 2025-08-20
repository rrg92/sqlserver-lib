/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Essa aqui foi a minha primeira tentativa de uma sys.dm_exec_sessions_Wait_stats, antes mesmo de saber que ela iria existir rs.
		A ideia era tentar pegar todos os waits que uma determinada sessão teria.
		Sem Traces ou XE... só com query...
		Você roda e para quando quiser (senão ele fica gravando eternamente).
		Quebrou alguns galhos...
		Hj em dia, com as versoes mais recente, não faz muito sentido, graças a sys.dm_exec_sessions_Wait_stats, que ja tem isso...
		Mas fica ai uma ideia;


*/

IF OBJECT_ID('tempdb..#Waits') IS NOT NULL
	DROP TABLE #Waits;
CREATE TABLE #Waits(
	ts datetime
	,session_id smallint
	,status varchar(400)
	,wait_type varchar(100)
	,wait_duration_ms  bigint
	,resource_description varchar(1500)
	,resource_address varbinary(1000)
	,wait_resumed_ms_ticks bigint
	,wait_started_ms_ticks bigint
	,task_bound_ms_ticks bigint
	,quantum_used bigint
	,worker_created_ms_ticks bigint
	,state varchar(400)
)

WHILE 1 = 1
BEGIN

	INSERT INTO
		#Waits
	SELECT
		 CURRENT_TIMESTAMP as TS
		,R.session_id
		,R.status
		,OT.wait_type
		,OT.wait_duration_ms
		,OT.resource_description
		,OT.resource_address
		,W.wait_resumed_ms_ticks
		,W.wait_started_ms_ticks
		,W.task_bound_ms_ticks
		,W.quantum_used
		,W.worker_created_ms_ticks
		,w.state
	FROM
		sys.dm_exec_requests R 
		LEFT JOIN
		sys.dm_os_waiting_tasks OT
			ON OT.session_id = R.session_id
		LEFT JOIN
		sys.dm_os_workers W
			ON W.task_address = R.task_address
	WHERE
		R.session_id > 50
		AND
		R.session_id = 52

	WAITFOR DELAY '00:00:00.500';
END

SELECT * fROM #Waits;