/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Retorna um resumo com estatísticas do plan cache. 
		ATENÇÃO: Esse script varre o plan cache, e portanto, pode demorar e até causar alguma pressão no seu ambiente.  
			Então, use com cautela.

		Cenários úteis em que usei: 
			Cheguei em um ambiente novo e precisei de uma rápida visão como estava o consumo do cache, para analisar algum probelma relacionado a isso.
*/


IF OBJECT_ID('tempdb..#PlanCacheData') IS NOT NULL
	DROP TABLE #PlanCacheData;

SELECT
	sql_handle
	,plan_handle
	,MIN(creation_time) as creation_Time
INTO
	#PlanCacheData
FROM
	sys.dm_exec_query_stats QS
GROUP BY
	sql_handle
	,plan_handle

CREATE CLUSTERED INDEX ixCluster ON #PlanCacheData(plan_handle);

IF OBJECT_ID('tempdb..#PlanCacheInfo') IS NOT NULL
	DROP TABLE #PlanCacheInfo;

SELECT
	*
INTO
	#PlanCacheInfo
FROM 
(
	SELECT 
		 CP.plan_handle
		,QS.sql_handle
		,QS.creation_time
		,CP.size_in_bytes
		,PA.attribute
		,PA.value
	FROM
		sys.dm_exec_cached_plans CP
		INNER JOIN
		(
			SELECT
 				sql_handle
				,plan_handle
				,MIN(creation_time) as creation_time
			FROM
				#PlanCacheData
			GROUP BY
				sql_handle
				,plan_handle
		) QS
			ON QS.plan_handle = CP.plan_handle
		CROSS APPLY
		sys.dm_exec_plan_attributes(CP.plan_handle) PA
	WHERE
		PA.attribute IN ('set_options','user_id','inuse_exec_context','misses_exec_context','free_exec_context','date_format')
) P
PIVOT
(MAX(value) FOR attribute IN (set_options,user_id,inuse_exec_context,misses_exec_context,free_exec_context,date_format) ) PA

SELECT
	*
FROM
	(
		SELECT
			COUNT(plan_handle) as NumPlanCache
			,SUM(CONVERT(bigint,inuse_exec_context)) as ExecContextInUse
			,SUM(CONVERT(bigint,free_exec_context)) as ExecContextFree
			,SUM(size_in_bytes*1.00/1024/1024) as PlanCacheSizeMB
			,COUNT(CASE WHEN user_id = -2 THEN plan_handle END) as NumPlansShareable
			,COUNT(CASE WHEN user_id != -2 THEN plan_handle END) as NumPlansSpecificUser
			,SUM(CASE WHEN user_id = -2 THEN size_in_bytes*1.00/1024/1024  END)as PlansShareableMB
			,SUM(CASE WHEN user_id != -2 THEN size_in_bytes*1.00/1024/1024 END) as PlansUserMB
		FROM 
			#PlanCacheInfo	
	) PG
	CROSS JOIN
	(
		SELECT 
			 COUNT(CASE WHEN CauseStatus = 1 THEN plan_handle END)							as QtdPlans
			,SUM(CASE WHEN CauseStatus = 1 THEN size_in_bytes*1.00/1024/1024 ELSE 0 END)	as UsedSpace
			,COUNT(CASE WHEN CauseStatus != 1 THEN plan_handle END)							as OtherCauseQtdPlans
			,SUM(CASE WHEN CauseStatus != 1 THEN size_in_bytes*1.00/1024/1024 ELSE 0 END)	as OtherCauseUsedSpace
		FROM 
			(
				SELECT
					*
					,ROW_NUMBER() over(PARTITION BY P.sql_handle,P.user_id ORDER BY creation_time) as CauseStatus
				FROM
					#PlanCacheInfo P
				WHERE
					P.user_id != -2
			) P	
	) PUS(User_QtdPlans,User_SpaceMB,User_OC_QtdPlans,User_OC_UsedSpace)
	CROSS JOIN
	(
		SELECT 
			 COUNT(CASE WHEN CauseStatus = 1 THEN plan_handle END)							as QtdPlans
			,SUM(CASE WHEN CauseStatus = 1 THEN size_in_bytes*1.00/1024/1024 ELSE 0 END)	as UsedSpace
			,COUNT(CASE WHEN CauseStatus != 1 THEN plan_handle END)							as OtherCauseQtdPlans
			,SUM(CASE WHEN CauseStatus != 1 THEN size_in_bytes*1.00/1024/1024 ELSE 0 END)	as OtherCauseUsedSpace
		FROM 
			(
				SELECT
					*
					,ROW_NUMBER() over(PARTITION BY P.sql_handle,P.set_options ORDER BY creation_time) as CauseStatus
				FROM
					#PlanCacheInfo P
			) P	
	) PSO(SetOpt_QtdPlans,SetOpt_SpaceMB,SetOpt_OC_QtdPlans,SetOpt_OC_UsedSpace)

