/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Uma query simples para agregar e trazer algumas informações rápidas sobre a instância.
		Útil para os casos em que não conhece a instância e quer ter uma visão geral.


*/



IF OBJECT_ID('tempdb..#Features') IS NOT NULL
	DROP TABLE #Features;

CREATE TABLE #Features( db sysname, name varchar(1000) );


IF OBJECT_ID('tempdb..#DatabaseSize') IS NOT NULL 
	DROP TABLE #DatabaseSize;

CREATE TABLE
	#DatabaseSize( Banco sysname, totalSize int, usedSize int );
	
EXEC sp_MSforeachdb '
	USE [?];
	
	insert into #Features
	select db_name(),feature_name from sys.dm_db_persisted_sku_features
	
	INSERT INTO #DatabaseSize
	SELECT
	 db_name()
	 ,SUM(size) 
	 ,SUM(FILEPROPERTY(name,''SpaceUsed''))
	FROM
		sys.database_files
'





select
     ServerName = @@SERVERNAME
	,D.*
    ,B.*
    ,BRS = B.BReq*1.00/DATEDIFF(SS,SI.sqlserver_start_time,CURRENT_TIMESTAMP)
    ,V = SERVERPROPERTY('ProductVersion')
	,E = SERVERPROPERTY('Edition')
    ,SS.SessionCount
    ,R.*
    ,TS = CURRENT_TIMESTAMP
    ,QS.*
    ,RamGB = SI.physical_memory_kb/1024/1024
	,FM.*
	,TM.*
	,MXM.*
	,MemUseG = TM.TotalMeGB - FM.FreeMeGB
	,[%M] = (TM.TotalMeGB - FM.FreeMeGB)*100/MXM.MaxMem
    ,CPUC = SI.cpu_count
	,CPU.*
	,SC.*
    ,SI.hyperthread_ratio
	,F.*
from
    sys.dm_os_sys_info SI
	CROSS JOIN (	
		SELECT  
			StartMonth = DATEADD(DD,DATEDIFF(DD,'19000101',GETDATE()),'19000101')
	) E
    CROSS JOIN (
		select 
			 DatabaseCount	= COUNT(*)
			,dbTotalSizeG		= sum(totalSize)/128/1024
			,dbUsedSizeG		= sum(usedSize)/128/1024
		from #DatabaseSize
    ) D   
    CROSS JOIN (
        SELECT BReq = PC.cntr_value
        FROM sys.dm_os_performance_counters PC
        WHERE PC.counter_name like '%Batch%Requests%'
    ) B
    CROSS JOIN (
        SELECT DataSize = SUM(size) FROM sys.master_files
        WHERE type_desc = 'ROWS'
    ) S
    CROSS JOIN (
        SELECT SessionCount = COUNT(*) FROM sys.dm_exec_sessions where
        session_id > 50 AND session_id != @@SPID
    ) SS
    CROSS JOIN (
        SELECT RequestCount = COUNT(*)
		,DMLRequestCount = COUNT(CASE WHEN command  IN ('SELECT','INSERT','UPDATE','DELETE') THEN session_id END ) 
		,DMLAvgTime = AVG(CASE WHEN command  IN ('SELECT','INSERT','UPDATE','DELETE') THEN total_elapsed_time END ) 
		,DMLAvgWaitTime = AVG(CASE WHEN command  IN ('SELECT','INSERT','UPDATE','DELETE') THEN wait_time END ) 
		,DMLAvgCPUTime = AVG(CASE WHEN command  IN ('SELECT','INSERT','UPDATE','DELETE') THEN cpu_time END ) 
		
		FROM sys.dm_exec_requests R
        where R.session_id > 50 and R.session_id != @@SPID
    ) R
    CROSS JOIN (
        SELECT RanCount = COUNT(*),RanAvgCPU = AVG(last_worker_time/1000.00),RanAvgDuration = AVG(last_elapsed_time/1000.00) FROM sys.dm_exec_query_stats QS
        WHERE QS.last_execution_time >= DATEADD(SS,-5,GETDATE())
    ) QS
	CROSS JOIN (
		SELECT FreeMeGB = cntr_value/1024/1024 FROM
		sys.dm_os_performance_counters
		WHERE counter_name like '%Free Memory (KB)%'
	) FM
	CROSS JOIN (
		SELECT TotalMeGB = cntr_value/1024/1024 FROM
		sys.dm_os_performance_counters
		WHERE counter_name like '%Total Server Memory (KB)%'
	) TM
	CROSS JOIN (
		SELECT MaxMem = CONVERT(bigint,value_in_use)/1024 FROM sys.configurations WHERE name = 'max server memory (MB)'
	) MXM
	outer APPLY (
		SELECT 
			[CPU_Avg] = AVG(C.SqlUtil)
			, [CPU_Max] = MAX(C.SqlUtil) 
			,CPU_Dt =  DATEDIFF(HH,MIN(EvtTime),MAX(EvtTime))
		FROM (
			SELECT
				*
			FROM ( 
 
				SELECT 
					SystemIdle = record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')
					,SqlUtil = record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') 
					,EvtTime = dateadd (ms, (X.[timestamp] - T.ms_ticks), GETDATE()) 
				FROM ( 
 
					SELECT 
						 timestamp
						, convert(xml, record) as record 
					FROM
						 sys.dm_os_ring_buffers 
					WHERE 
						ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
				) X 
				CROSS JOIN
				(
					select  ms_ticks from  sys.dm_os_sys_info 
				) T
 
			) as C
		) C

	) CPU
	CROSS APPLY(
		SELECT
			SchVon = COUNT(CASE WHEN status = 'VISIBLE ONLINE' THEN scheduler_id END)
			,SchVof = COUNT(CASE WHEN status = 'VISIBLE OFFLINE' THEN scheduler_id END)
		FROM
			sys.dm_os_schedulers S
	) SC
	outer apply (
		SELECT DISTINCT name as 'data()' FROM #Features FOR XML PATH(''),TYPE
	) F(Features)

	


