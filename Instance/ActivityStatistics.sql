/*#info

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Uma quer que usei muito para trazer estatísticas de execução, para ter uma visão rápida de tudo que estava rodando no servidor a qualquer momento.
		Com essa query vc sabe a quantidade de requisicoes rodando, o tempo da mais antiga, quantas estao rodando de fato, quantas estao esperando cpu (runnable), em wait, etc.
		Pra um visão rápida, sem muita precisão, é uma boa consulta.

*/

DECLARE
	@qsStatsTime int
	,@highRunMS int

SET @highRunMS = 1000;

SELECT
	*
FROM
	(
		SELECT
			AllRequests				= COUNT(*)			
			,RequestCount			= COUNT(CASE WHEN RS.IsNormal = 1 THEN RS.session_id END)															
			,OldestRequest			= MIN(CASE WHEN RS.IsNormal = 1 THEN RS.start_time END)		
			,OldestTime				= DATEDIFF(SS,MIN(CASE WHEN RS.IsNormal = 1 THEN RS.start_time END),CURRENT_TIMESTAMP)
			,Running				= COUNT(CASE WHEN RS.status = 'running' AND RS.IsNormal = 1 THEN RS.session_id END)	
			,Runnables				= COUNT(CASE WHEN RS.status = 'runnable' AND RS.IsNormal = 1  THEN RS.session_id END)	
			,Waiting				= COUNT(CASE WHEN RS.status = 'suspended' AND RS.IsNormal = 1  THEN RS.session_id END)		
			,HighRun				= COUNT(CASE WHEN RS.HighRun = 1 AND RS.IsNormal = 1  THEN RS.session_id END)		
			,AvgCPUFactor			= AVG(CASE WHEN RS.IsNormal = 1 THEN RS.CPUFactor END)		
			,MaxCPUFactor			= MAX(CASE WHEN RS.IsNormal = 1 THEN RS.CPUFactor END)	
			,AvgReads				= AVG(CASE WHEN RS.IsNormal = 1 THEN CONVERT(bigint,RS.reads) END)		
			,AvgWrites				= AVG(CASE WHEN RS.IsNormal = 1 THEN CONVERT(bigint,RS.writes) END)		
			,AvgWaiting				= AVG(CASE WHEN RS.IsNormal = 1 THEN CONVERT(bigint,RS.wait_time) END)		
			,AvgElapsed				= AVG(CASE WHEN RS.IsNormal = 1 THEN CONVERT(bigint,RS.total_elapsed_time) END)				
		FROM
			(	
				SELECT
					*
					,CASE WHEN isAdmin = 0 AND isForcedWait = 0 THEN 1 ELSE 0 END IsNormal
					,CONVERT(bigint,CASE 
						DATEDIFF(MS,RS.start_time,CURRENT_TIMESTAMP) WHEN 0 THEN 0
						ELSE RS.cpu_time*1.00/DATEDIFF(MS,RS.start_time,CURRENT_TIMESTAMP)
					END) as CPUFactor
					,CONVERT(bigint,CASE
						WHEN RS.total_elapsed_time > @highRunMS THEN 1
						ELSE 0
					END) as HighRun
				FROM
				(
					SELECT	
						*
						,CASE
							WHEN R.command IN ('DBCC') THEN 1
							WHEN R.command LIKE '%BACKUP%' THEN 1
							ELSE 0
						END  isAdmin
						,CASE
							WHEN R.command IN ('WAITFOR') THEN 1
							WHEN R.command LIKE '%BACKUP%' THEN 1
							ELSE 0
						END  isForcedWait
					FROM
						sys.dm_exec_requests R
					WHERE
						R.session_id > 50
						AND
						R.session_id != @@SPID
				) RS
			) RS
	) R
	CROSS JOIN
	(
		SELECT
			 AVG(last_worker_time/1000)		AS S_MediaCPU
			,AVG(last_elapsed_time/1000)	AS S_MediaTempo
			,MAX(last_execution_time)		AS S_LastExecuted
			,COUNT(*)						AS S_QtdQueries
		FROM
			sys.dm_exec_query_Stats
		WHERE
			last_execution_time > DATEADD(SS,-ISNULL(@qsStatsTime,1),CURRENT_TIMESTAMP)
	) QS
OPTION(RECOMPILE) --> Evita que o plano fique em cache!