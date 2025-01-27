/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Tentando calcular o uso de CPU usando as DMVs de os_thrads, que contém as infos de cpu direto da API do Windows, para cada thread.
		Aqui eu estava tentando obter mais precisão no consumo de CPU, mas, raramente usei essa.
*/

IF OBJECT_ID('tempdb..#CPUTimes') IS NOT NULL
	DROP TABLE #CPUTimes;

SELECT
	 TK.session_id
	,TK.task_address
	,TK.exec_context_id
	,T.os_thread_id
	,T.usermode_time
	,T.kernel_time
	,TS = CURRENT_TIMESTAMP
INTO
	#CPUTimes
FROM
	sys.dm_os_workers W
	JOIN
	sys.dm_os_threads T 
		on T.worker_address = W.worker_address
	JOIN
	sys.dm_os_tasks TK
		ON TK.worker_address = W.worker_Address
WHERE
	TK.session_id > 50

WAITFOR DELAY '00:00:01.000'; --> Aguarda 1 segundo (intervalo de monitoramento)


SELECT
	R.session_id
	,R.task_address
	,R.exec_context_id
	,Intervalo		= DATEDIFF(ms,TS,CURRENT_TIMESTAMP)
	,R.usermode_time-U.usermode_time as CPUSpend		
	,R.kernel_time-U.kernel_time as KernelSpend		
	,(R.usermode_time+R.kernel_time)-(U.usermode_time+U.kernel_time)	 as TotalSpend				
FROM
	(
		SELECT
			 TK.session_id
			,TK.task_address
			,TK.exec_context_id
			,T.os_thread_id
			,T.usermode_time
			,T.kernel_time
		FROM
			sys.dm_os_workers W
			JOIN
			sys.dm_os_threads T 
				on T.worker_address = W.worker_address
			JOIN
			sys.dm_os_tasks TK
				ON TK.worker_address = W.worker_Address
		WHERE
			TK.session_id > 50
	) R
	LEFT JOIN
	#CPUTimes U
		ON R.session_id = U.session_id
		AND R.exec_context_id = U.exec_context_id
		AND R.os_thread_id = U.os_thread_id
ORDER BY
	TotalSpend DESC