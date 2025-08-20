/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Uma query simpels para me trazer as infos de requests cpu e memória.

*/

SELECT
	DI.DatabaseCount
	,SI.cpu_count
	,SI.hyperthread_ratio
	,SI.physical_memory_kb/1024/1024 as MemoGB
	,SES.SessionsCounts
	,REQ.RequestsCount
FROM
(
	SELECT 
		COUNT(*) DatabaseCount
	FROM 
		sys.databases D
	WHERE
		D.database_id > 4
) DI
CROSS JOIN
sys.dm_os_sys_info SI
CROSS JOIN
(
	SELECT
		COUNT(*)  as SessionsCounts
	FROM
		sys.dm_exec_sessions S
	WHERE
		S.session_id > 50
) SES
CROSS JOIN
(
	SELECT
		COUNT(*)  as RequestsCount
	FROM
		sys.dm_exec_requests R
	WHERE
		R.session_id > 50
) REQ

