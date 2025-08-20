/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Traz as tops X queries que rodaram (estão no cache ainda) mais lentas.
		Você poe trocar o criterio, alterando o ORDER BY na CTE.

*/

WITH qTOP AS
(
SELECT TOP 10
	 db_name( st.dbid )											as Banco
	,ISNULL(object_name( st.objectid, st.dbid ),'Ad Hoc')		as Objeto
	,SUBSTRING(
		 CASE WHEN st.text IS NULL THEN '' ELSE st.text END
		,qs.statement_start_offset/2
		,CASE qs.statement_end_offset WHEN -1 THEN LEN( st.text ) ELSE (qs.statement_end_offset- qs.statement_start_offset)/2 END
	)											as Trecho
	,qs.plan_generation_num						as Compilacoes
	,qs.total_worker_time/qs.execution_count	as CPU
	,qs.total_elapsed_time						as TempDec
	,qs.last_execution_time						as UltimaExec
	,qs.max_logical_writes						as Escritas
	,qs.max_logical_reads						as Leituras
FROM
				sys.dm_exec_query_stats qs
	OUTER APPLY	sys.dm_exec_sql_text( qs.sql_handle ) st
	OUTER APPLY sys.dm_exec_query_plan( qs.plan_handle ) qp
ORDER BY
	CPU	 DESC
)
SELECT
	 Banco
	,Objeto
	,Compilacoes
	,CPU
	,Trecho
	,UltimaExec	
FROM
	qTOP