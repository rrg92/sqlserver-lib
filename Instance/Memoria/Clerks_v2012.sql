/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Script com o total dos clerks a partir do sql 2012, que mudou algumas colunas!

*/


USE master;
GO

select CONVERT(varchar(30),Grupo) as Grupo
,(AnySizeAllocator+VirtualAlloc)*1.00/1024 as TamGB


from (
select 
	C.Grupo
	,SUM(C.pages_kb)*1.00/1024					AS  AnySizeAllocator
	,SUM(C.virtual_memory_committed_kb)*1.00/1024		AS  VirtualAlloc
from 
	(
		SELECT
			MC.*
			,CASE
				WHEN MC.type like '%BUFFERPOOL%' THEN MC.type 	
				WHEN MC.type like '%CP'  THEN 'PLAN_CACHE' 	
				WHEN MC.type like '%PHDR'  THEN 'PLAN_CACHE'	
				WHEN MC.type like '%OBJECTSTORE%' THEN 'PLAN_CACHE'	
				ELSE 'OUTROS' 
			END as Grupo
		FROM
			sys.dm_os_memory_clerks MC
	)  C
GROUP BY
	C.Grupo WITH ROLLUP
	) t
	
	select * From sys.dm_os_performance_counters where instance_name like '%memory manager%'