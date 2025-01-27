/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Retorna apenas as sessões que estão em running, isto é, o worker associado está de fato executando no scheduler (state = running).
		Note que não necessariamente ele estará na cpu do SO, pois isso não é controlado pelo SQL!
		Se aqui tem muita coisa, e no seu Windows tá consumo baixo de CPU do sql, tem algo muito estranho... 
		Pode ser, por exemplo, algum AV ou driver, DPC, etc.
*/

SELECT
	*
FROM
(
	SELECT
		T.session_id
		,COUNT(W.worker_address) as QtdWorkers
		,COUNT(CASE WHEN S.is_idle = 0 and w.state = 'running' then W.worker_address END)		as QtdRunningWorks
	FROM
		(
			SELECT
				T.task_address
				,CASE	
					WHEN T.session_id < 51 THEN t.session_id
					ELSE t.session_id
				END as session_id
			FROM
				sys.dm_os_tasks T
		) T
		INNER JOIN
		sys.dm_os_workers W
			ON W.task_address = T.task_address
		LEFT JOIN
		sys.dm_os_schedulers S
			ON s.active_worker_address = W.worker_address
	GROUP BY
		T.session_id WITH ROLLUP
) TAT
WHERE
	TAT.QtdRunningWorks > 0
ORDER BY
	QtdWorkers DESC