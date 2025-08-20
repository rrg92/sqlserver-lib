/*#info 

	# autor 
		Rodrigo Ribeiro Gomes 
		
	# descricao 
		Algumas queries que usei para monitoramento de memory grants na instancia.
		Uma das primeiras.

*/


--> agrupado por wait... 
--> se nao tiver em wait, vai entrar no grupo null, que são as que conseguiram o grant.!
SELECT 
	R.wait_type
	,SUM(MG.granted_memory_kb)	as TotalGrantedKB
	,COUNT(*)					as SessionCount
	,MIN(R.start_time)			as OldestRequestTime
	,AVG(R.wait_time)			as AvgWaitTime
	,AVG(R.cpu_time)			as AvgCpuTime
	,SUM(MG.granted_memory_kb*100.00/RS.available_memory_kb) as UsedPercentual
FROM 
	sys.dm_exec_query_memory_grants MG 
	LEFT JOIN 
	sys.dm_exec_requests R 
		ON R.session_id = MG.session_id
	LEFT JOIN 
	sys.dm_exec_sessions S
		 ON S.session_id = R.session_id
	INNER JOIN
	sys.dm_exec_query_resource_semaphores RS
		ON 	RS.resource_semaphore_id = MG.resource_semaphore_id
			AND
			RS.pool_id = MG.pool_id --> 2005 nao tem essa coluna
WHERE
	R.session_id != @@spid
GROUP BY
		R.wait_type



--> Aqui é o detalhe!
SELECT 
	 S.session_id
	,R.wait_type
	,MG.granted_memory_kb
	,S.host_name
	,RS.max_target_memory_kb
	,RS.available_memory_kb
FROM 
	sys.dm_exec_query_memory_grants MG 
	LEFT JOIN 
	sys.dm_exec_requests R 
		ON R.session_id = MG.session_id
	LEFT JOIN 
	sys.dm_exec_sessions S
		 ON S.session_id = R.session_id
	LEFT JOIN
	sys.dm_exec_query_resource_semaphores RS
		ON 	RS.resource_semaphore_id = MG.resource_semaphore_id
			AND
			RS.pool_id = MG.pool_id --> 2005 nao tem essa coluna
WHERE
	R.session_id != @@spid
ORDER BY
	R.start_time