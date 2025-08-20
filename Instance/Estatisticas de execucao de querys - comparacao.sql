/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Uma query simples para comparar as estatísticas de execução de procedures.
        Ali one tem "nome proc" você especificar o filtro para achar as procs (E bancos)... Especificando mais de uma, você pode compará-las...
        Útil para comparar o desempenho de uma proc X e Y, sendo que a Y foi uma versão otimizada de X que você quer testar.

*/


IF OBJECT_ID('tempdb..#TabelaResultados') IS NOT NULL
  DROP TABLE #TabelaResultados;

SELECT
  db_name(st.dbid)                                     AS Banco
  ,ISNULL(object_name(st.objectid, st.dbid), 'Ad Hoc') AS Objeto
  ,SUBSTRING(CASE
               WHEN st.TEXT IS NULL THEN ''
               ELSE st.TEXT
             END, qs.statement_start_offset / 2, CASE qs.statement_end_offset
                                                   WHEN -1 THEN LEN(st.TEXT)
                                                   ELSE ( qs.statement_end_offset - qs.statement_start_offset ) / 2
                                                 END)  AS Trecho
  ,qs.plan_generation_num                              AS Compilacoes
  ,qs.last_worker_time                                 AS CPU
  ,qs.last_elapsed_time                                AS TempDec
  ,qs.last_execution_time                              AS UltimaExec
  ,qs.last_logical_writes                              AS Escritas
  ,qs.last_logical_reads                               AS Leituras
--	,last_execution_time,execution_count,total_worker_time,last_worker_time
--	,last_logical_writes,last_logical_reads,last_elapsed_time
INTO   #TabelaResultados
FROM
  sys.dm_exec_query_stats qs
  OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) st
  OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE  st.objectid IN ( OBJECT_ID('')  ) -- nome proc
       AND ST.DBID = DB_ID('') -- nome banco

--ORDER BY
--	CPU DESC
SELECT
  row_number() OVER( ORDER BY Objeto )
  ,Objeto
  ,CAST(1.00 * SUM(cpu) / 1000 AS DECIMAL(10, 2))                                                    AS CPU
  ,CONVERT(VARCHAR(15), MAX( UltimaExec ), 103) + ' ' + CONVERT(VARCHAR(12), MAX( UltimaExec ), 114) AS UltimaExec
  ,SUM(ESCRiTAS)                                                                                     AS Escritas
  ,SUM(leituras)                                                                                     AS Leituras
  ,CAST(1.00 * SUM(TempDec) / 1000 AS DECIMAL(10, 2))                                                AS TempoDecorrido
FROM
  #TabelaResultados
GROUP  BY Objeto
