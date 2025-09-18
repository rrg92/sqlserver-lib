/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes

	# Descricao 
		Um script para você analisar os principais gargalos de waits da instancia atualmente.
		A vantagem de usar esse script é que você vai ter uma visão dos waits que estão ocorrendo.
		Pode ser útil para identificar um wait incomum e fora do padrão.
		Não significa necessariamente um problema, mas pode te dar norte de quais waits estão sendo usados.
		Se você tiver um baseline, pode te ajudar a mapear algum comportamento.
		
		A lógica é simples: Vamos pegar os waits, aguardar 1 segundo, e pegar novamente.
		Tiramos a diferença... Esse é o nosso "historico" de waits nesse intervalo de 1 segundo.
		E, para considerar o que está em execução, pegando também os waits em curso, da sys.dm_os_waiting_tasks
		
		A coluna Src indica de onde a informacao veio.
		H - Veio do histórico (comparando o atual com o anterior)
		R - Veio da requests, comparando as requisicoes que estão em wait no momento.
*/


IF OBJECT_ID('tempdb..#Wait1') IS NOT NULL
	DROP TABLE #Wait1;

IF OBJECT_ID('tempdb..#Wait2') IS NOT NULL
	DROP TABLE #Wait2;



SELECT
	*
	,Dt_Log = GETDATE()
INTO
	#Wait1
FROM
	sys.dm_os_wait_stats W1

WAITFOR DELAY '00:00:01'

SELECT
	*
	,Dt_Log = GETDATE()
INTO
	#Wait2
FROM
	sys.dm_os_wait_stats W1

SELECT
	 Src = 'H'
	,W1.wait_type
	,TaskDiff	= W2.waiting_tasks_count - W1.waiting_tasks_count
	,WaitMsDiff = W2.wait_time_ms - W1.wait_time_ms
	,SignalDiff = W2.signal_wait_time_ms  - W1.signal_wait_time_ms
FROM
	#Wait1 W1
	JOIN
	#Wait2 W2
		ON W2.wait_type = W1.wait_type
WHERE
	W2.waiting_tasks_count - W1.waiting_tasks_count > 0

UNION ALL

SELECT
	Src = 'R'
	,WT.wait_type
	,TaskDiff = COUNT(*)
	,WaitMs = SUM(WT.wait_duration_ms)
	,WaitSignal = NULL
FROM
	sys.dm_os_waiting_tasks WT
WHERE
	WT.session_id IN (SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process = 1)
GROUP BY
	WT.wait_type

ORDER BY
	WaitMsDiff desc