/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Traz informacoes sobre todos os indexes fulltext e processos de population ativo (todas do banco atual)
		
		
*/

select 
	 c.name							as Nome
	,c.path							as Cam
	,c.is_default					as Padrao
	,fac.memory_address				as AddrM
	,fac.name						as ftcNome
	,fac.status						as St
	,fac.previous_status			as prSt
	,fac.is_paused					as Paused
	,fac.status_description			as StDesc
	,fac.active_fts_index_count		as idxAt
	,fac.auto_population_count				as ppAuto
	,fac.manual_population_count			as ppM
	,fac.full_incremental_population_count	as ppINC
	,fac.row_count_in_thousands		as RowCnt
	,object_name(fip.table_id)		as Tab
	,fip.memory_address				as fipAddr
	,fip.population_type_description as popDesc
	,fip.is_clustered_index_scan	as ClusterSc
	,fip.range_count
	,fip.completed_range_count		as RangCntC
	,fip.outstanding_batch_count	as OBC
	,fip.status
	,fip.status_description
	,fip.completion_type
	,fip.completion_type_description
	,fip.worker_count
	,fip.start_time
	,fip.incremental_timestamp
from 
sys.fulltext_catalogs c
left join
sys.dm_fts_active_catalogs fac on fac.catalog_id = c.fulltext_catalog_id
							and fac.database_id = db_id()
left join
sys.dm_fts_index_population fip ON fip.catalog_id = c.fulltext_catalog_id
						and fip.database_id = db_id()