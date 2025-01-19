/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Recomendo você olha a CPU\RequestDelta.sql antes, entender ela e depois voltar nessa, pois é uma variação dela.
		
		Esta script faz quase a mesma a coisa que RequestDelta, mas co um pouco mais de simplicidade para coletar rapidamente agrupando por objeto!
		Com isso, se você tem um ambiente com muita procedure que roda rapido, talvez ver o que consumindo ali agregando pelo nome, dê um resultado bem rapido

		O legal que coloquei é que para queries adhoc, ele vai usar o quer hash, agrupando por queries com o "mesmo texto"
*/

IF OBJECT_ID('tempdb..#UsoCPUAnterior') IS NOT NULL
	DROP TABLE #UsoCPUAnterior;

SELECT
	R.session_id
	,R.request_id
	,R.start_time
	,R.cpu_time
	,CURRENT_TIMESTAMP as DataColeta
INTO
	#UsoCPUAnterior
FROM
	sys.dm_exec_requests R
WHERE	
	R.session_id != @@SPID

WAITFOR DELAY '00:00:01.000'; --> Aguarda 1 segundo (intervalo de monitoramento)

SELECT O,QtdQueris = COUNT(*), TotalCpu = SUM(CPUIntervalo) FROM (
SELECT
	R.session_id
	,R.request_id
	,R.start_time
	,Intervalo		= ISNULL(DATEDIFF(ms,DataColeta,CURRENT_TIMESTAMP),R.total_elapsed_time)
	,CPUIntervalo	= ISNULL(R.cpu_time-U.cpu_time,R.cpu_time)
	,[%Intervalo]	= ISNULL((R.cpu_time-U.cpu_time)*100/DATEDIFF(ms,DataColeta,CURRENT_TIMESTAMP),ISNULL(R.cpu_time*100/NULLIF(R.total_elapsed_time,0),0))
	,Duracao		= R.total_elapsed_time 
	,CPUTotal		= R.cpu_time															
	,[%Total]		= R.cpu_time*100/NULLIF(R.total_elapsed_time,0)	
	,SUBSTRING(EX.text,R.statement_start_offset/2 + 1, ISNULL((NULLIF(R.statement_end_offset,-1) - R.statement_start_offset)/2 + 1,LEN(EX.text)) )		as Trecho						
	,O = CASE 
			WHEN R.session_id  <= 50 THEN 'SYS'
			WHEN OBJECT_NAME(EX.objectid,EX.dbid) IS NULL THEN CONVERT(varchar,R.query_hash,2)
			ELSE OBJECT_NAME(EX.objectid,EX.dbid)
		 END
	,T.TH
FROM
	sys.dm_exec_requests R
	LEFT JOIN
	#UsoCPUAnterior U
		ON R.session_id = U.session_id
		AND R.request_id = U.request_id
		AND R.start_time = U.start_time
	outer apply sys.dm_exec_sql_text( R.sql_handle ) as EX
	CROSS APPLY (
		SELECT TH = COUNT(*) FROM sys.dm_os_tasks T WHERE T.session_id = R.session_id
	) T
WHERE	
	R.session_id != @@SPID
) S
GROUP BY
	O 
ORDER BY 3 DESC


