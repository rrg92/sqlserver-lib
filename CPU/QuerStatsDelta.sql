/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		O mesmo que RequestsDelta, porém usando a sys.dm_exec_query_stats... 
		ISto é, consigo olhar o que há rodou há pouco segundos...
		Isso pode me ajudar a pegar queries extremamente rápidas, mas que rodam aos montes e consomem muita CPU na soma!
*/


IF OBJECT_ID('tempdb..#StatsBefore') IS NOT NULL
	DROP TABLE #StatsBefore;

IF OBJECT_ID('tempdb..#StatsAfter') IS NOT NULL
	DROP TABLE #StatsAfter;

IF OBJECT_ID('tempdb..#QueryStatsDelta') IS NOT NULL
	DROP TABLE #QueryStatsDelta;

declare @Start datetime = DATEADD(SS,-1,GETDATE())

select
	query_hash
	,last_worker_time
	,execution_count
	,st.text
	,creation_time
	,last_execution_time
	,qs.plan_handle
	,qs.statement_start_offset
	,qs.statement_end_offset
	,AvgCpuTime = total_worker_time*1.00/execution_count
	,total_worker_time
	,CollectTime = getdate()
	,ObjectName = OBJECT_NAME(st.objectid,st.dbid)
	,DbName = DB_NAME(st.dbid)
into
	#StatsBefore
from
	sys.dm_exec_query_stats qs
	cross apply
	sys.dm_exec_sql_text(qs.sql_handle) st
where
	qs.last_execution_time >= @Start

waitfor delay '00:00:01'

select
	query_hash
	,last_worker_time
	,execution_count
	,st.text
	,creation_time
	,last_execution_time
	,qs.plan_handle
	,qs.statement_start_offset
	,qs.statement_end_offset
	,AvgCpuTime = total_worker_time*1.00/execution_count/1000.
	,total_worker_time
	,CollectTime = getdate()
	,ObjectName = OBJECT_NAME(st.objectid,st.dbid)
	,DbName = DB_NAME(st.dbid)
into
	#StatsAfter
from
	sys.dm_exec_query_stats qs
	cross apply
	sys.dm_exec_sql_text(qs.sql_handle) st
where
	qs.last_execution_time >= @Start


SELECT
	 DbName = ISNULL(A.DbName,pa.DbName)
	,t.batch
	,Trecho = q.qx
	,A.ObjectName
	,C.Interval
	,LastCpu = CONVERT(decimal(10,2),A.last_worker_time/1000.)
	,ExecDelta = A.execution_count - B.execution_count
	,C.CpuDelta
	,AvgDelta	= CONVERT(decimal(10,2),C.CpuDelta/(Interval/1000.))
	,[CpuDelta%] = CONVERT(int,C.CpuDelta*100/Interval)
	,[AvgDelta%] = CONVERT(int,(CONVERT(decimal(10,2),C.CpuDelta/(Interval/1000.))/1000)*100)
	,CpuBefore = B.total_worker_time/1000.
	,CpuAfter = A.total_worker_time/1000.
	,ExecBefore = B.execution_count
	,ExecAfter = A.execution_count
	,A.plan_handle
	,A.query_hash
	,A.creation_time
	,A.last_execution_time
into
	#QueryStatsDelta
FROM
	#StatsAfter A
	LEFT JOIN
	#StatsBefore B
		ON B.plan_handle = A.plan_handle
		AND B.statement_start_offset  = A.statement_start_offset
		and B.statement_end_offset = A.statement_end_offset
	CROSS APPLY (
		SELECT
			CpuDelta = CONVERT(decimal(10,2),(A.total_worker_time - B.total_worker_time)/1000.)
			,Interval = DATEDIFF(MS,B.CollectTime,A.CollectTime)
	) C
	cross apply (
		select 
			DbName = DB_NAME(CONVERT(int,value)) from sys.dm_exec_plan_attributes(A.plan_handle) pa
		where pa.attribute = 'dbid'
	) pa
	cross apply (
		select
			[processing-instruction(q)] = (
			REPLACE
			(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			CONVERT
			(
			NVARCHAR(MAX),
			A.text COLLATE Latin1_General_Bin2
			),
			NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
			NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
			NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
			NCHAR(0),
			N''
			)
			)
			for xml path(''),TYPE
	) t(batch)
	cross apply (
		select
			[processing-instruction(q)] = (
			REPLACE
			(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
			CONVERT
			(
			NVARCHAR(MAX),
			SUBSTRING(A.text,A.statement_start_offset/2 + 1, ISNULL((NULLIF(A.statement_end_offset,-1) - A.statement_start_offset)/2 + 1,LEN(A.text)) ) COLLATE Latin1_General_Bin2
			),
			NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
			NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
			NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
			NCHAR(0),
			N''
			)
			)
			for xml path(''),TYPE
	) q(qx)

SELECT
	*
FROM
	#QueryStatsDelta
WHERE
	ExecDelta > 0
ORDER BY
	CpuDelta DESC


select AvgCpuPercent = c.TotalCPU*100/(si.cpu_count*1000)
,TotalCPU
,EstCpuCnt = TotalCPU/1000
,MaxCPUTime = (si.cpu_count*MaxInterval)
,TotalCpu = si.cpu_count
from 
	( SELECT TotalCPU = SUM(CpuDelta), MaxInterval = MAX(Interval) from #QueryStatsDelta ) c
	cross join 
	sys.dm_os_sys_info si

select 
	q.*
	,qh.batch
	,qh.Trecho
	,qh.ObjectName
from (
SELECT
	query_hash
	,Qtd = count(*)
	,CpuTotal = sum(CpuDelta)
FROM
	#QueryStatsDelta
group by
	query_hash
) q
outer apply (
	select top 1 * from #QueryStatsDelta d where d.query_hash = q.query_hash
) qh
order by 
	CpuTotal desc