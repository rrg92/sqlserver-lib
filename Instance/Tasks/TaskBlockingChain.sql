/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Retorna informações de blocks entre tasks... 
		Isso é útil para checar sessões que estão causando bloqueios entre si (mesma sessão, diferenes tasks).
		Geralmente em casos de paralelismo
*/
	
select 
	WT.session_id
	,WT.wait_duration_ms
	,WT.wait_type
	,BT.session_id as BlockingSessionID
	,BT.exec_context_id as BlockingContext
from 
	sys.dm_os_waiting_tasks WT
	LEFT JOIN
	sys.dm_os_tasks  BT
		ON BT.task_address = WT.blocking_task_address
where 
	WT.session_id IN (select TOP 1 session_id from 	sys.dm_os_waiting_tasks WT group by session_id order by COUNT(*) desc)

SELECT
	 R.session_id
	 ,COUNT(DISTINCT T.task_address) as TotalTasks
	 ,COUNT(DISTINCT CASE WHEN OT.waiting_task_address IS NULL THEN  T.task_address END) as RunningTasks
	 ,COUNT(DISTINCT CASE WHEN OT.waiting_task_address IS NOT NULL THEN  T.task_address END) as BlockedTasks
	 ,COUNT(DISTINCT CASE WHEN BT.session_id = T.session_id  THEN  T.task_address END) as BlockSameSession
	--,T.exec_context_id
	--,OT.blocking_task_address
FROM
	sys.dm_exec_requests R
	LEFT JOIN
	sys.dm_os_tasks T
		ON T.request_id = R.request_id
		AND T.session_id = R.session_id
	LEFT JOIN
	sys.dm_os_waiting_tasks OT
		ON OT.waiting_task_address = T.task_address
	LEFT JOIN
	sys.dm_os_tasks BT
		ON BT.task_address = OT.blocking_task_address
WHERE
	R.session_id > 50 AND R.session_id != @@SPID
	--AND
	--OT.blocking_task_address IS NULL
GROUP BY
	 R.session_id