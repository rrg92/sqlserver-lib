/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Mais algumas informações de threads.
		Fiz isso apenas para ter de prontidão caso precisasse... Mas, não lembro de usar isso comfrequência...
		Se nao me engano, foi mais para estudos
*/

SELECT
     R.session_id
    ,DbName = DB_NAME(R.database_id)
    ,R.command
    ,R.wait_type
    ,R.total_elapsed_time
    ,R.wait_time
    ,R.cpu_time
	,WSigTime	= CASE WHEN W.wait_started_ms_ticks = 0 THEN SI.ms_ticks - NULLIF(W.wait_resumed_ms_ticks,0) ELSE 0 END
	,WWaitTime	= SI.ms_ticks -NULLIF(W.wait_started_ms_ticks,0)
	,Start_quantum
	,RqStatus	= R.status
	,WkStatus	= W.state
	,W.is_preemptive
    ,S.scheduler_id
    ,S.is_idle
    ,S.runnable_tasks_count
    ,S.cpu_id
    ,S.status
FROM
    sys.dm_exec_requests R
    LEFT JOIN (
        sys.dm_os_tasks T
        INNER JOIN
        sys.dm_os_workers W
            ON W.worker_address = T.worker_address
        INNER JOIN
        sys.dm_os_schedulers S
            ON S.scheduler_address = W.scheduler_address
    ) ON T.request_id = R.request_id
    AND T.session_id = R.session_id
	CROSS JOIN sys.dm_os_sys_info AS SI 
WHERE
	R.scheduler_id IS NOT NULL
ORDER BY
    scheduler_id