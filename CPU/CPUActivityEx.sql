/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Essa é uma das primeiras versões que criei para obter info PRECISA de CPU de uma maneira agregada!
		
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


SELECT
	OS.identificador	
	,MIN(OS.start_time)					as MenorTempoStart
	,SUM(OS.cpu_time)					as CPUTime
	,COUNT(OS.task_address)				as NumTasks
	,COUNT(OS.worker_address)			as NumWorkers
	,COUNT(CASE WHEN OS.scheduler_idle = 1 AND OS.ActiveWorker = 1 THEN OS.scheduler_address END) as ActiveIdles 
	,MAX(OS.Working)					as Working
	,MAX(OS.os_thread_id)				as ThreadID
	,MAX(OS.thread_address)				as ThreadAddr
	,MAX(OS.CurrentRequest)				as CurrentRequest
	,AVG(CPUFactor)						as CPUFactor
FROM 
	(
		SELECT
			 CASE
				WHEN R.session_id < 50 THEN -50
				ELSE R.session_id
			END as identificador
			,R.session_id
			,R.request_id
			,R.start_time 
			,R.status as request_status
			,R.command
			,R.wait_type
			,R.wait_time
			,R.cpu_time
			,T.task_address
			,T.task_state
			,W.worker_address
			,W.state
			,S.scheduler_address
			,S.status as scheduler_status
			,S.is_idle as scheduler_idle
			,CASE
				WHEN  S.active_worker_address = W.worker_address THEN 1
				ELSE 0
			END AS ActiveWorker
			,CASE
				WHEN  S.active_worker_address = W.worker_address AND S.is_idle = 0 THEN 1
				ELSE 0
			END as Working
			,TH.os_thread_id
			--,DENSE_RANK() OVER(PARTITION BY R.session_id,R.request_id ORDER BY W.quantum_used-W.start_quantum DESC) as RankThreadTime
			,CASE
				WHEN R.session_id = @@SPID THEN 1
				ELSE 0
			END as CurrentRequest
			,TH.thread_address
			,R.cpu_time*1.00/NULLIF(R.total_elapsed_time,0) as CPUFactor
		FROM
			sys.dm_exec_requests R
			LEFT JOIN
			(
				sys.dm_os_tasks T
				INNER JOIN
				sys.dm_os_workers W		
					ON W.worker_address = T.worker_address
				INNER JOIN
				sys.dm_os_threads TH
					ON TH.worker_address = W.worker_address
				INNER JOIN
				sys.dm_os_schedulers S 
					ON S.scheduler_address = W.scheduler_address
			) 
				ON R.session_id = T.session_id
				AND R.request_id = T.request_id
	) OS

GROUP BY
	identificador WITH ROLLUP
ORDER BY
	Working DESC,CPUTime DESC 

	


--SELECT * FROM sys.dm_os_threads;
--select * from sys.dm_os_sys_info
--select * from sys.dm_os_schedulers
	
--SP_WHOISACTIVE

/*
select t.session_id,th.os_thread_id from sys.dm_os_threads th 
inner join
sys.dm_os_workers W 
	on w.worker_address = th.worker_address
inner join
sys.dm_os_tasks t
	on t.task_address = w.task_address
where  th.os_thread_id = 11712
**/



--sp_whoisactive @delta_interval = 2

