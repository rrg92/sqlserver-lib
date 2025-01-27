/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Traz informações agregadas dos schedulers e threads usados por cada sessão!
		Visão rápida de paralelismo.
		Hoje, na RequestsDelta.sql, isso já está lá bem mais completo!
		
*/

SELECT
	--TH.os_thread_id
	--,TH.affinity
	--,W.state
	--,TK.task_state
	 TK.session_id_ex
	,COUNT(distinct TK.task_address)													as Tasks
	,COUNT(distinct CASE WHEN TK.task_state = 'RUNNING' THEN TK.task_address END)		as TasksRunning
	,COUNT(DISTINCT W.worker_address)													as NumWorkers
	,COUNT(DISTINCT CASE WHEN TK.task_state = 'RUNNING' THEN S.scheduler_address END)	as NumSchedulersUso
	,COUNT(DISTINCT TH.os_thread_id)													as NumThreads
FROM
	(
		SELECT 
			* 
			,CASE	
				WHEN TK.session_id > 50 THEN session_id 
				ELSE -50
			END as session_id_ex
		FROM 
			 sys.dm_os_tasks TK
	) TK
	JOIN
	sys.dm_os_workers W 
		ON W.worker_address = TK.worker_address
	JOIN
	sys.dm_os_schedulers S 
		ON S.scheduler_address = W.scheduler_address
	JOIN
	sys.dm_os_threads TH
		ON TH.worker_address = W.worker_address
WHERE
	TK.session_id <> @@SPID
GROUP BY
	TK.session_id_ex WITH ROLLUP	
ORDER BY
	CASE WHEN session_id_ex IS NULL THEN 1 ELSE 0 end desc,NumSchedulersUso DESC
	
