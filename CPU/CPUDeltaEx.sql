/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Um CPU Delta um pouco mais enfeitado...
		Faz várias coletas,ao invés de 2 e depois calcula o delta entre a primeira e a última!
		Não lembro exatamente o porque faço várias coletas, mas acho que era pra garantir ter o máximo de info intermediária para usar se precisar!
		
*/

DECLARE
	@collectsCount int
	,@TimeToCollect varchar(12)
	,@CPU100MS smallint
;

SET @collectsCount = 20;
SET @TimeToCollect = 1000;
SET @CPU100MS = 1000;

----> Internal structures
IF OBJECT_ID('tempdb..#requests') IS NOT NULL
	DROP TABLE #requests;

IF OBJECT_ID('tempdb..#processed') IS NOT NULL
	DROP TABLE #processed;

IF OBJECT_ID('tempdb..#report') IS NOT NULL
	DROP TABLE #report;

DECLARE
	@TimePerCollect int
	,@CollectTimeFormat varchar(13)
	,@StartTime datetime
	,@CollectNumber bigint
;

--> COLLECT PHASE

	-- Calculates time need for wait between collects.
	SET  @TimePerCollect = @TimeToCollect/@collectsCount;
	-- Store the final time to wait between collects, in the format 'HH:MM:SS.MMM'
	SET @CollectTimeFormat = RIGHT(CONVERT(varchar(23),DATEADD(ms,@TimePerCollect,0),121),12);

	

	--> Initialize @CollectNumber
	SET @CollectNumber = 1;
	-- Initialize the temp table.
	SELECT @CollectNumber as CollectNumber,CURRENT_TIMESTAMP as CollectTimestamp,* INTO #requests FROM sys.dm_exec_requests WHERE 1 = 2;

	SET @StartTime = CURRENT_TIMESTAMP;
	WHILE( DATEDIFF(ms,@StartTime,CURRENT_TIMESTAMP) <= @TimeToCollect )
	BEGIN
		--> Get the data!
		INSERT INTO		
			#requests 
		SELECT 
			@CollectNumber,CURRENT_TIMESTAMP
			,*
		FROM 
			sys.dm_exec_requests;

		--> Increase...
		SET @CollectNumber  = @CollectNumber + 1;

		--. Waitfor time to collect again.
		WAITFOR DELAY @CollectTimeFormat;
	END


--> BUILD PHASE

	SELECT
		F.session_id
		,F.request_id
		,F.start_time
		,F.task_address
		,F.sql_handle
		,~CONVERT(bit,L.session_id) Finished
		,L.cpu_time - F.cpu_time as CPUUsed
		,l.cpu_time CPUAcc
	INTO
		#processed
	FROM
		#requests F
		OUTER APPLY 
		(
			SELECT	TOP 1
				*
			FROM
				#requests L
			WHERE
				L.session_id = F.session_id
				AND
				AND
				L.request_id = F.request_id
				AND
				L.start_time = F.start_time
				L.task_address = F.task_address
				AND
				L.CollectNumber > F.CollectNumber --> Last must be a greater number of first!
			ORDER BY
				L.CollectNumber DESC
		) L
	WHERE
		F.CollectNumber = 1

--> Generating reporting...

	SELECT
		P.session_id
		,P.request_id
		,P.start_time
		,QINFO.ProcName
		,P.CPUUsed
		,(P.CPUUsed*100.00)/(SI.cpu_count*@CPU100MS) as EstimatedCPU
		,P.CPUAcc
	INTO
		#report
	FROM
		#processed P
		CROSS JOIN
		sys.dm_os_sys_info SI
		INNER JOIN
		(
			SELECT
				 QH.sql_handle
				,OBJECT_NAME(ST.objectid,ST.dbid) as ProcName
			FROM
			(
				SELECT DISTINCT
					sql_handle
				FROM
					#processed
			) QH
			CROSS APPLY
			sys.dm_exec_sql_text(QH.sql_handle) ST
		) QINFO
			ON QINFO.sql_handle = P.sql_handle
	ORDER BY
		CPUUsed DESC


--> Final data for caller use

	SELECT
		*
		--,DATEDIFF(MS,R.start_time,CURRENT_TIMESTAMP) Live
		,CPUUsed*100.00/@TimeToCollect as CPUUsedInterval
		--,CPUAcc*100.00/DATEDIFF(MS,R.start_time,CURRENT_TIMESTAMP) as CPUUsedLive
	FROM
		#report R
	ORDER BY
		CPUUsed DESC