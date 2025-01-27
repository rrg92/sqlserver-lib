/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Versão light do cpu delta!
		DEve ter sido um dos primeiros scripts que eu fiz para ter isso...
		.\RequestsDElta.sql é mais completo!
*/


IF OBJECT_ID('tempdb..#first') IS NOT NULL
	DROP TABLE #first;

IF OBJECT_ID('tempdb..#second') IS NOT NULL
	DROP TABLE #second;


SELECT * INTO #first FROM sys.dm_exec_requests
WAITFOR DELAY '00:00:01.000'
SELECT * INTO #second FROM sys.dm_exec_requests


SELECT
	S.session_id
	,s.request_id
	,s.start_time
	,'#' as [#]
	,F.session_id
	,F.request_id
	,F.start_time
	,(S.cpu_time - F.cpu_time) as CPUGasto
FROM
	#second S
	INNER JOIN
	#first F
		ON F.session_id = S.session_id
		AND F.request_id = S.request_id
		AND F.start_time = S.start_time
		AND F.task_address = S.task_address
ORDER BY
	CPUGasto DESC


SELECT
	SUM(CASE WHEN S.session_id IS NULL THEN 1 ELSE 0 END) as QtdRquestsNovos
	,SUM(CASE WHEN F.session_id IS NULL THEN 1 ELSE 0 END) as QtdRquestsFinalizados
	,COUNT(*) as TotalCollects
FROM
	#second S
	FULL JOIN
	#first F
		ON F.session_id = S.session_id
		AND F.request_id = S.request_id
		AND F.start_time = S.start_time
		AND F.task_address = S.task_address