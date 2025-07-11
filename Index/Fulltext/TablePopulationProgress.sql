/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Traz informacoes sobre o progresso do population de um fulltext index em uma tabela especifica.
		
		
*/

DECLARE	
	@TableId int = OBJECT_ID('NomeTabela')

SELECT 
	 T.object_id
	,name
	,R.TotalRows
	,IndexedRows		= OBJECTPROPERTYEX(T.object_id,'TableFulltextItemCount')
	,PendingChanges		= OBJECTPROPERTYEX(T.object_id,'TableFullTextPendingChanges')
	,FailCount			= OBJECTPROPERTYEX(T.object_id,'TableFulltextFailCount')
	,TotalProcessed		= OBJECTPROPERTYEX(T.object_id,'TableFulltextDocsProcessed')
	,PopStatus			= OBJECTPROPERTYEX(T.object_id,'TableFulltextPopulateStatus') 
	,Progress			= CONVERT(bigint,OBJECTPROPERTYEX(T.object_id,'TableFulltextItemCount'))*100/R.TotalRows
	,PopType			= FP.population_type_description
	,FP.range_count
	,FP.completed_range_count
	,FP.outstanding_batch_count
	,FP.status_description
	,FI.incremental_timestamp
	,FI.crawl_type_desc
	,FI.crawl_start_date
	,FI.crawl_end_date
	,FI.data_space_id
	,FI.change_tracking_state_desc
from
	sys.tables t
	cross apply
	(
		select TotalRows = sum(rows) from sys.partitions p 
		where p.object_id = t.object_id
		and p.index_id <= 1
	) R
	left join
	sys.dm_fts_index_population FP
		ON FP.table_id = T.object_id
	left join
	sys.fulltext_indexes FI
		ON FI.object_id = T.object_id
where
	t.object_id = @TableId

select * from sys.dm_fts_outstanding_batches where table_id = @TableId
select * from sys.dm_fts_population_ranges 
select * from sys.fulltext_index_fragments where table_id = @TableId


