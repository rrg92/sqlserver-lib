/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Traz quais sessões estão usando scheduler e a respectiva thread no SO.
		E se for em paralelo, traz a thread que mais consome de CPU de todas as threads da query!
		
*/

SELECT 
	r.session_id
	,r.cpu_time 
	,E.*
FROM 
	sys.dm_exec_requests r 
	CROSS APPLY
	(
		SELECT
			COUNT(EX.scheduler_address) as SchedulerUso
			,MAX(CASE WHEN EX.THRankTime = 1 THEN  EX.ThreadID END) as MaxThread
			,COUNT(EX.worker_address) as NumWorkers
		FROM
			(
				SELECT 
					S.scheduler_address
					,TH.os_thread_id  AS ThreadID
					,ROW_NUMBER() OVER(ORDER BY TH.kernel_time + TH.usermode_time DESC) as THRankTime
					,W.worker_address
				from 
					sys.dm_os_tasks T
					INNER JOIN
					sys.dm_os_workers W 
						ON W.worker_address = T.worker_address
					INNER JOIN
					sys.dm_os_threads TH
						ON TH.worker_address = T.worker_address
					left JOIN	
						sys.dm_os_schedulers S	
						ON W.worker_address = S.active_worker_address
						AND w.state = 'RUNNING'
				WHERE
					T.session_id = r.session_id
					AND
					T.request_id = R.request_id
			) EX
	) E 
WHERE
	--R.session_id > 50
	--AND
	R.session_id <> @@SPID
ORDER BY 
	E.SchedulerUso DESC, R.cpu_time DESC
	

--sp_whoisactive 58
	
	/*
	select t.session_id,th.os_thread_id from sys.dm_os_threads th 
	inner join
	sys.dm_os_workers W 
		on w.worker_address = th.worker_address
	inner join
	sys.dm_os_tasks t
		on t.task_address = w.task_address
	where  t.session_id = 1
	**/
