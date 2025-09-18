/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Faz várias coletas das sessoes em wait. 
		Util para analisar o progressos dos waits que uma sessão tinha... 
		Isso foi antes de surgir a DMV sys.dm_exec_sessions_Wait_Stats, que traz isso melhor;
			
			


*/

declare 
	@session bigint
	,@MaxCollects int = 100

if object_id('tempdb..#waitinfo') is not null drop table #waitinfo;
select 
	 convert(datetime,null) as start_time
	,session_id
	,wait_type
	,wait_duration_ms 
	,W.wait_started_ms_ticks
	,W.wait_resumed_ms_ticks
	,CONVERT(bigint,NULL) as RunnableTime
into 
	#waitinfo  
from 
	sys.dm_os_waiting_tasks WT
	JOIN
	sys.dm_os_workers W
		ON W.task_address = WT.waiting_task_address  
where 1 = 2


declare @i int
while @i <= @MaxCollects
begin
	set @i += 1;
	 insert into 
		#waitinfo
	select 
		 R.start_time
		,R.session_id
		,ISNULL(wt.wait_type,R.wait_type)
		,ISNULL(wt.wait_duration_ms,R.wait_time)
		,W.wait_started_ms_ticks
		,W.wait_resumed_ms_ticks
		,CASE
			WHEN W.state = 'RUNNABLE' THEN SI.ms_ticks-W.wait_resumed_ms_ticks
			ELSE 0
		END as RunnableTime
	from 
		sys.dm_exec_requests R
		JOIN
		sys.dm_os_workers W
			ON W.task_address = R.task_address 
		CROSS JOIN
		sys.dm_os_sys_info SI
		LEFT JOIN
		sys.dm_os_waiting_tasks wt
			on wt.waiting_task_address = R.task_Address
	 where 
		R.session_id > 50
		 and 
		 R.session_id != @@spid
		 and
		 (R.wait_type IS NOT NULL OR W.state = 'RUNNABLE')
		 and 
		 (
			R.session_id = @session
			OR
			@session is null
		)
end


SELECT
	 start_time
	,session_id
	,wait_type
	,SUM(wait_duration_ms)	as Total
	,MIN(wait_duration_ms)	as Minimum
	,MAX(wait_duration_ms)	as Maximum
	,SUM(RunnableTime)		AS RunnableTime
	,COUNT(*)				as Qty
FROM
	(
		select 
			*
			,ROW_NUMBER() OVER(PARTITION BY wait_started_ms_ticks ORDER BY wait_duration_ms DESC) as Seq
 		from	
			#waitinfo
	) WI
WHERE
	WI.Seq = 1
GROUP BY
	 start_time
	,session_id
	,wait_type

	