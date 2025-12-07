/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Uma das primeiras queris que fiz que trazia uma visão geral do consumo de memória do sql e alguns componentes.

*/


IF OBJECT_ID('tempdb..#MemoInfo') IS NOT NULL
	DROP TABLE #MemoInfo;
CREATE TABLE #MemoInfo(component varchar(400), memoMB decimal(30,2) );

IF OBJECT_ID('tempdb..#SysInfo') IS NOT NULL
	DROP TABLE #SysInfo;
CREATE TABLE #SysInfo( memoryGB decimal(10,2), maxStackSize decimal(10,2) );


DECLARE
	@tsql_Cmd nvarchar(4000)
	,@MemoSource nvarchar(500)	
	,@PhysicalMemorySource nvarchar(500)	
;

IF EXISTS(SELECT * FROM sys.all_columns WHERE object_id = OBJECT_ID('sys.dm_os_memory_clerks') AND name = 'pages_kb')
	SET @MemoSource = 'MC.pages_KB + MC.virtual_memory_committed_kb'
ELSE
	SET @MemoSource = 'MC.single_pages_kb + MC.multi_pages_kb + MC.virtual_memory_committed_kb + MC.awe_allocated_kb'

IF EXISTS(SELECT * FROM sys.all_columns WHERE object_id = OBJECT_ID('sys.dm_os_sys_info') AND name = 'physical_memory_kb')
	SET @PhysicalMemorySource = 'physical_memory_kb/1024.00/1024'
ELSE
	SET @PhysicalMemorySource = 'physical_memory_in_bytes/1024.00/1024/1024'


SET @tsql_Cmd = N'
	INSERT INTO
		#MemoInfo
	SELECT
		MC.type
		,('+@MemoSource+')*1.00/1024 as MemoMB
	FROM
		sys.dm_os_memory_clerks MC
		
		
	INSERT INTO
		#SysInfo
	select	'+@PhysicalMemorySource+',stack_size_in_bytes*max_workers_count/1024.00/1024/1024 from sys.dm_os_sys_info
'

EXEC sp_executesql @tsql_Cmd;

SELECT
	 Description 	= ISNULL(ComponentGroup,'Total')
	,UsedGB			= CONVERT( decimal(10,2), SUM(memoMB)/1024.00 )
FROM
	(
		SELECT
			 MI.*
			,CASE
				WHEN MI.component like '%BUFFERPOOL%' THEN 'BUFFER_POOL'	
				WHEN MI.component like '%CP'  THEN 'PLAN_CACHE' 	
				WHEN MI.component like '%PHDR'  THEN 'PLAN_CACHE'	
				WHEN MI.component like '%OBJECTSTORE%' THEN 'PLAN_CACHE'	
				ELSE 'OUTROS' 
			END as ComponentGroup
		FROM
			#MemoInfo MI
		WHERE	
			MI.component not like '%RESERVATIONS%'
			
		UNION ALL
			
		SELECT 
			'QUERYMEMORY_USED'
			,SUM(used_memory_kb)/1024.00 
			,'QUERYMEMORY_USED'
		FROM
			sys.dm_exec_query_memory_grants
			
			
		UNION  ALL
		
		SELECT 
			'FREE_MEMORY'
			,cntr_value/1024.00 
			,'FREE_MEMORY'
		FROM 
			sys.dm_os_performance_counters 
		WHERE 
			counter_name like 'Free Memory (KB)%' 
			and 
			object_name like '%:Memory Manager%'

		UNION ALL

		SELECT 
			'FREE_MEMORY'
			,cntr_value/128.00
			,'FREE_MEMORY'
		FROM 
			sys.dm_os_performance_counters 
		WHERE 
			counter_name like 'Free Pages%' 
			and 
			object_name like '%:Buffer Manager%'

		UNION ALL

		SELECT 
			'THREADSTACK'
			,SUM(stack_bytes_committed)/1024.00/1024
			,'THREADSTACK'
		from 
			sys.dm_os_threads
		
		UNION ALL 

		SELECT 
			 'DLL_DWA'
			,SUM(region_size_in_bytes) / 1024./1024. 
			,'DLL_DWA'
		FROM sys.dm_os_virtual_address_dump
		WHERE region_allocation_base_address IN (SELECT base_address FROM sys.dm_os_loaded_modules)
	) MI
GROUP BY	
	ComponentGroup WITH ROLLUP
	
UNION ALL

SELECT
	 'RESERVATIONS'
	,SUM(memoMB)/1024.
FROM
	#MemoInfo MI
WHERE	
	MI.component like '%RESERVATIONS%'
	
UNION ALL

selecT 'QUERYMEMORY_GRANT',SUM(granted_memory_kb)/1024./1024 from sys.dm_exec_query_memory_grants


	
	
SELECT 
	 SqlRamGB			= CONVERT( decimal(10,2), physical_memory_in_use_kb /1024.00/1024)
	,SqlAllGB			= CONVERT( decimal(10,2), virtual_address_space_committed_kb/1024.00/1024)
	,[Ram%All]			= memory_utilization_percentage
	,MaxMemoryConfig	= Mx.value
	,MaxMemory			= Mx.value_in_use
	,MinMemoryConfig	= Mn.value
	,MinMemory			= Mn.value_in_use
	,MaxStackGB			= SI.maxStackSize
	,TotalRamGB			= SI.memoryGB
FROM 
	sys.dm_os_process_memory
	cross join
	(select value_in_use,value from sys.configurations where name like 'max server memory%') Mx
	cross join
	(select value_in_use,value from sys.configurations where name like 'min server memory%') Mn
	cross join
	#SysInfo SI




SELECT counter_name,instance_name,cntr_value FROM sys.dm_os_performance_counters WHERE counter_name like '%Lazy%'
UNION ALL
SELECT counter_name,instance_name,cntr_value FROM sys.dm_os_performance_counters WHERE counter_name like '%page life%'
