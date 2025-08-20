/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Por anos, essa query foi minha sp_whoisactive.
		Antes de conhecer a sp_whoisactie (e mais tarde a PowerIsActive, do power alerts), eu usei muito isso aqui para saber como estava o servidor.
		Uma query que me trazia as infos básicas de tudo que estava rodando. Me ajudou muito a responder rapidamente a problemas de várias natureza (locks, cpu, disco, etc.)

*/

use master
go

select 
s.session_id			Sessao
,s.login_name			Login
--,s.host_name			HOST
--,user_name(r.user_id)	Usuario
,r.cpu_time				CPUr
,convert(decimal(5,2),CONVERT(bigint,r.cpu_time)*1.00/NULLIF(CONVERT(bigint,r.total_elapsed_time),0)) as CPUf
,r.total_elapsed_time	TMPr
,r.status				
,r.blocking_session_id	BLK
,r.wait_type
,r.percent_complete
,r.arithabort
,r.command
,r.reads
,r.granted_query_memory
,r.last_wait_type
,SUBSTRING(ex.text,r.statement_start_offset/2 + 1, ISNULL((NULLIF(r.statement_end_offset,-1) - r.statement_start_offset)/2 + 1,LEN(ex.text)) )		as Trecho
,object_name( ex.objectid,ex.dbid ) objeto
,db_name( r.database_id ) Banco
,TSK.TaskCount
,r.sql_handle
,RequestPlan = qp.query_plan
,CachedPLan = p.query_plan
,PlanText = p.planText
,qg.*
from
	sys.dm_exec_sessions s
inner join sys.dm_exec_requests r on r.session_id = s.session_id
outer apply sys.dm_exec_sql_text( r.sql_handle ) as ex
outer apply (
	select 
		count(*) as TaskCount
	from
		sys.dm_os_tasks T
	WHERE
		T.session_id = r.session_id
		AND
		T.request_id = r.request_id
) TSK
outer apply sys.dm_exec_query_plan(r.sql_handle) qp
outer apply (
	select
		qp.*
		,planText = tqp.query_plan
	from
		sys.dm_exec_query_stats qs
		outer apply
		sys.dm_exec_query_plan(qs.plan_handle) qp
		outer apply
		sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) tqp
	where
		qs.sql_handle = r.sql_handle
) p
outer apply (
	select
		qp.*
		,grantQueryPlan  = qp.query_plan
		,qg.reserved_worker_count
		,qg.used_worker_count
	from
		sys.dm_exec_query_memory_grants qg
		outer apply
		sys.dm_exec_query_plan(qg.plan_handle) qp
	where
		qg.session_id = s.session_id
		and
		qg.request_id = r.request_id
) qg
where 
	s.session_id > 50
	and 
	s.session_id <> @@spid
	and
	s.is_user_process = 1
--	and
--	wait_type = 'LCK_M_X'
order by
	r.cpu_time desc


	
