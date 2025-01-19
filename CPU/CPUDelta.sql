/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Recomendo você olha a CPU\RequestDelta.sql antes, entender ela e depois voltar nessa, pois é uma variação dela.

		Essa query é nova! Éu acho que criei em 2022, após já ter entrado e encarado muitos desafios na Power Tuning.

		O script RequestDelta.sql funciona bem para queries acima de 1 segundo!
		Queries que rodam abaixo desse tempo, a coisa já começa a ficar complicada!

		Então, eu tive a sacada: Ora, se tem query rodando rápido que eu não estou vendo pq ela já rodaram, talvez eu consiga pegar isso na query_stats!
		E aí nasceu isso aqui.
		Confesso que nunca usei em um cenário real que me ajudou de fato (até pq já usava bastante o Power Alerts, então como lá tem mais info, isso aqui ficou pra segundo plano). 
		Mas, eu deixei esse script pq ainda sim, ela pode me mostrar algumas informações secretas, pois, de fato, a query_Stats tem informações valiosas sobre queries que rodaram há pouco tempo!

		CUIDADO: A query_stats pode conter muita linha! Se você sentir que essa query ta demorand ou impactando no ambiente, pare ela imediatamente!

		A coluna src quando = 's' india que o resultado é da query_stats, e quando r, indica que é a sys.dm_exec_requests (realtime)
*/

IF OBJECT_ID('tempdb..#CpuSnap') IS NOT NULL
	DROP TABLE #CpuSnap;


CREATE TABLE #CpuSnap (
	 ts				datetime
	,n				int
	,id				varchar(200) not null
	,src			char(1) -- r = request, s = stats
	,SessionId		int
	,RequestId		int
	,query_hash		varbinary(10)
	,StartTime		datetime
	,Executions		bigint
	,TotalCpuTime	bigint		-- micro
	,TotalTime		bigint		-- micro
	,LastWorkerTime	bigint		-- micro
	,LastTime		bigint	
	,AvgCpuTime		bigint		-- micro
	,SqlHandle		varbinary(100)
	,PlanHandle		varbinary(100)
	,StmtStart		bigint
	,StmtEnd		bigint
	,LastExecTime	datetime
	,command		varchar(1000)
	,Did			int	-- database id
	,Oid			int	-- object_id
	,TotalReads		bigint
	,TotalWrites	bigint
	,TotalLReads	bigint
)

create clustered index ixCluster on #CpuSnap(id,n)

declare @Start datetime = DATEADD(SS,-1,GETDATE())
declare @i int = 0

while @i < 2
begin
	set @i += 1

	if @i > 0
		waitfor delay '00:00:01';

	INSERT INTO	
		#CpuSnap
	SELECT
		GETDATE()
		,@i
		,id = CHECKSUM('r',R.session_id,R.request_id,R.start_time)
		,'r'
		,R.session_id
		,R.request_id
		,R.query_hash
		,R.start_time
		,1
		,CONVERT(bigint,R.cpu_time)*1000
		,R.total_elapsed_time
		,NULL
		,NULL
		,NULL
		,R.sql_handle
		,R.plan_handle
		,R.statement_start_offset
		,R.statement_end_offset
		,NULL
		,R.command
		,R.database_id
		,NULL
		,R.reads
		,R.writes
		,R.logical_reads
	FROM
		sys.dm_exec_requests R
	WHERE
		R.session_id != @@SPID
	
	UNION ALL

	SELECT
		GETDATE()
		,@i
		,id = CHECKSUM('s',qs.plan_handle,qs.statement_start_offset,qs.statement_end_offset)
		,'s'
		,NULL
		,NULL
		,qs.query_hash
		,qs.creation_time
		,execution_count
		,qs.total_worker_time
		,qs.total_elapsed_time
		,qs.last_worker_time
		,qs.last_elapsed_time
		,AvgCpuTime = total_worker_time*1.00/execution_count
		,sql_handle
		,qs.plan_handle
		,qs.statement_start_offset
		,qs.statement_end_offset
		,qs.last_execution_time
		,NULL
		,st.dbid
		,st.objectid
		,NULL
		,NULL
		,NULL
	from
		sys.dm_exec_query_stats qs
		cross apply
		sys.dm_exec_sql_text(qs.sql_handle) st
	where
		qs.last_execution_time >= @Start

end


select
	 pa.DbName
	,c2.src
	,batch = COALESCE(ObjectName,t.batch)
	,stmt = Stmt.x
	,ExecDelta = c2.Executions - c1.Executions
	,C.*
	,[%cpu] = CONVERT(decimal(10,2),CpuDelta*100./C.Interval)
	,c2.AvgCpuTime
	,c2.SessionId
	,c2.SqlHandle
	,c2.PlanHandle
	,P.* 
	--,Trecho = q.qx
	--,A.ObjectName
	--,C.Interval
	--,LastCpu = CONVERT(decimal(10,2),A.last_worker_time/1000.)
	--,ExecDelta = A.execution_count - B.execution_count
	--,C.CpuDelta
	--,AvgDelta	= CONVERT(decimal(10,2),C.CpuDelta/(Interval/1000.))
	--,[CpuDelta%] = CONVERT(int,C.CpuDelta*100/Interval)
	--,[AvgDelta%] = CONVERT(int,(CONVERT(decimal(10,2),C.CpuDelta/(Interval/1000.))/1000)*100)
	--,CpuBefore = B.total_worker_time/1000.
	--,CpuAfter = A.total_worker_time/1000.
	--,ExecBefore = B.execution_count
	--,ExecAfter = A.execution_count
	--,A.plan_handle
	--,A.query_hash
	--,A.creation_time
	--,A.last_execution_time
from
	#CpuSnap c1
	join
	#CpuSnap c2
		on c2.id = c1.id
	cross apply (
		select 
			DbName		= DB_NAME(CONVERT(int,value))
			,DatabaseId = CONVERT(int,value)
		from sys.dm_exec_plan_attributes(c2.PlanHandle) pa
		where pa.attribute = 'dbid'
	) pa
	CROSS APPLY (
		SELECT
			 CpuDelta = CONVERT(decimal(10,2),(c2.TotalCpuTime - c1.TotalCpuTime)/1000.)
			,Interval = DATEDIFF(MS,c1.ts,c2.ts)
			,CpuTotal = c2.TotalCpuTime/1000.
			,LastCpu = c2.LastWorkerTime/1000.
	) C
	outer APPLY (
		select 
			QueryText = st.text
			,ObjectName = OBJECT_NAME(st.objectid,isnull(st.dbid,pa.DatabaseId))
			,QueryStmt = CONVERT(NVARCHAR(MAX),
							SUBSTRING(st.text,c2.StmtStart/2 + 1, ISNULL((NULLIF(c2.StmtEnd,-1) - c2.StmtStart)/2 + 1,LEN(st.text)) ) COLLATE Latin1_General_Bin2
						)
			
		from
			sys.dm_exec_sql_text(c2.PlanHandle) st
	) Q
	outer APPLY (
		select 
			StmtPlan = CONVERT(XML,qp.query_plan)
		from
			sys.dm_exec_text_query_plan(c2.PlanHandle,c2.StmtStart,c2.StmtEnd) qp
	) P
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
			Q.QueryText COLLATE Latin1_General_Bin2
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
			QueryStmt,
			NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
			NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
			NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
			NCHAR(0),
			N''
			)
			)
		for xml path(''),TYPE
	) Stmt(x)
WHERE
	c1.n = 1
	and
	c2.n = 2
	AND
	c.CpuDelta > 0
ORDER BY
	c.CpuDelta DESC

/*


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

*/