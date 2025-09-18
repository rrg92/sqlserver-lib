USE master
GO

IF OBJECT_ID('dbo.sp_getResponseStats') IS NULL
	EXEC ('CREATE PROC dbo.sp_getResponseStats AS SELECT 1 StubVersion')
GO


ALTER PROCEDURE
	sp_getResponseStats 
	(
		@LastQueryTime int = 1
		,@highRunMS int = 1000
		,@highDisk int = 5
		,@highNet int = 5
	)
WITH
	RECOMPILE -- Avoids this enter on cache for contabilitities
AS
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	/*
		Created by Rodrigo Ribeiro gomes
		www.thesqltimes.com 
	*/

	SELECT
		*
		,PorcEspera = Waiting*100/NULLIF(RequestCount,0)
		,PorcHighs	= HighRun*100/NULLIF(RequestCount,0)
	FROM
		(
			SELECT
				AllRequests				= COUNT(*)			
				,RequestCount			= COUNT(CASE WHEN RS.IsNormal = 1 THEN RS.session_id END)															
				,OldestRequest			= MIN(CASE WHEN RS.IsNormal = 1 THEN RS.start_time END)		
				,OldestTime				= DATEDIFF(SS,MIN(CASE WHEN RS.IsNormal = 1 THEN RS.start_time END),CURRENT_TIMESTAMP)
				,Running				= COUNT(CASE WHEN RS.status = 'running' AND RS.IsNormal = 1 THEN RS.session_id END)	
				,Runnables				= COUNT(CASE WHEN RS.status = 'runnable' AND RS.IsNormal = 1  THEN RS.session_id END)	
				,Waiting				= COUNT(CASE WHEN RS.status = 'suspended' AND RS.IsNormal = 1 AND RS.RealWaitsCount > 0  THEN RS.session_id END)		
				,InParalell				= COUNT(CASE WHEN RS.IsNormal = 1 AND RS.WorkerCount > 1  THEN RS.session_id END)	
				,HighRun				= COUNT(CASE WHEN RS.HighRun = 1 AND RS.IsNormal = 1  THEN RS.session_id END)			
				,AvgCPUFactor			= AVG(CASE WHEN RS.IsNormal = 1 THEN RS.CPUFactor END)
				,MaxCPUFactor			= MAX(CASE WHEN RS.IsNormal = 1 THEN RS.CPUFactor END)
				,AvgReads				= AVG(CASE WHEN RS.IsNormal = 1 THEN CONVERT(bigint,RS.reads) END)		
				,AvgWrites				= AVG(CASE WHEN RS.IsNormal = 1 THEN CONVERT(bigint,RS.writes) END)		
				,AvgWaiting				= AVG(CASE WHEN RS.IsNormal = 1 THEN CONVERT(bigint,RS.wait_time) END)		
				--,AvgElapsed				= AVG(CASE WHEN RS.IsNormal = 1 THEN RS.total_elapsed_time END)	
				,AvgWorkers				= AVG(CASE WHEN RS.IsNormal = 1 THEN RS.WorkerCount END)	
				,MaxWorkers				= MAX(CASE WHEN RS.IsNormal = 1 THEN RS.WorkerCount END)		
			FROM
				(	
					SELECT
						*
						,CASE WHEN isAdmin = 0 AND isForcedWait = 0 THEN 1 ELSE 0 END IsNormal
						,CASE 
							DATEDIFF(SS,RS.start_time,CURRENT_TIMESTAMP) WHEN 0 THEN 0
							ELSE RS.cpu_time*100.00/DATEDIFF(SS,RS.start_time,CURRENT_TIMESTAMP)
						END as CPUFactor
						,CASE
							WHEN RS.total_elapsed_time > @highRunMS THEN 1
							ELSE 0
						END as HighRun
						,CASE
							WHEN W.WorkerCount > 1 THEN 1
							ELSE 0
						 END IsParalell
					FROM
					(
						SELECT	
							*
							,CASE
								WHEN R.command IN ('DBCC','DbccFilesCompact') THEN 1
								WHEN R.command LIKE '%BACKUP%' THEN 1
								ELSE 0
							END  isAdmin
							,CASE
								WHEN R.command IN ('WAITFOR','BROKER_RECEIVE_WAITFOR') THEN 1
								WHEN R.command LIKE '%BACKUP%' THEN 1
								ELSE 0
							END  isForcedWait
						FROM
							sys.dm_exec_requests R
							OUTER APPLY (
								SELECT
									COUNT(*) AS RealWaitsCount
								FROM
									sys.dm_os_waiting_tasks OT
								WHERE
									OT.session_id = R.session_id
									AND
									OT.wait_type NOT IN ('CXPACKET')
							) STA
						WHERE
							R.session_id > 50
							AND
							R.session_id != @@SPID
					) RS
					OUTER APPLY 
					(
						SELECT	
							COUNT(W.worker_address) as WorkerCount
						FROM
							sys.dm_os_tasks T WITH(nolock)
							INNER JOIN
							sys.dm_os_workers W WITH(nolock)
								ON W.worker_address = T.worker_address
						WHERE
							T.session_id = RS.session_id
							AND
							T.request_id = RS.request_id
					) W
				) RS
		) R
		CROSS JOIN
		(
			SELECT
				 S_MediaCPU		= AVG(last_worker_time/1000.00)
				,S_MediaTempo	= AVG(last_elapsed_time/1000.00)
				,S_LastExecuted	= MAX(last_execution_time)	
				,S_QtdQueries	= COUNT(*)	
			FROM
				sys.dm_exec_query_Stats
			WHERE
				last_execution_time > DATEADD(SS,-ISNULL(@LastQueryTime,1),CURRENT_TIMESTAMP)
		) QS
		CROSS JOIN
		(
			SELECT
				IODisk_Pending			=	COUNT(CASE WHEN IOR.TYPE = 'disk' THEN IOR.IOID END)
				,IODisk_AvgPending		=	AVG(CASE WHEN IOR.TYPE = 'disk' THEN IOR.WAIT END)			
				,IODisk_Oldest			=	MAX(CASE WHEN IOR.TYPE = 'disk' THEN IOR.WAIT END)				
				,IODisk_Highs			=	COUNT(CASE WHEN IOR.TYPE = 'disk' AND IOR.IsHigh = 1 THEN IOR.IOID END)	
				,IONet_Pending			=	COUNT(CASE WHEN IOR.TYPE = 'network' THEN IOR.IOID END)		
				,IONet_Oldest			=	MAX(CASE WHEN IOR.TYPE = 'network' THEN IOR.WAIT END)							 
				,IONet_AvgPending		=	AVG(CASE WHEN IOR.TYPE = 'network' THEN IOR.WAIT END)								
				,IONet_Highs			=	COUNT(CASE WHEN IOR.TYPE = 'network' AND IOR.IsHigh = 1 THEN IOR.IOID END)			
			FROM
				(
					SELECT
						IOR.*
						,IOR.io_completion_request_address	as IOID
						,IOR.io_pending_ms_ticks			as WAIT
						,IOR.io_type						as TYPE
						,CASE 
							WHEN IOR.io_pending_ms_ticks > @highDisk THEN 1
							WHEN IOR.io_pending_ms_ticks > @highNet THEN 1
							ELSE 0
						END IsHigh
					FROM
						sys.dm_io_pending_io_requests IOR
				) IOR
		) IOS
		CROSS JOIN
		(
			SELECT
				SUM(work_queue_count) as PendingTasks
				,SUM(runnable_tasks_count) as RunnableTasks
			FROM
				sys.dm_os_schedulers S
			WHERE
				S.status = 'VISIBLE ONLINE'
		) SDLS
	OPTION(RECOMPILE) --> Avoids caching of this query
GO