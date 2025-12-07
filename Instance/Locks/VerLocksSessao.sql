/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Ver os locks de um sessão + ifnormacoes dos objetos lockados.
		Atencao: a sys.dm_tran_locks le diretamente de uma estrutura em memoria do SQL...
		E ela pode ser GIGANTE...Usar com muito cuidado isso!

*/

select 
	 tl.resource_type
	,tl.resource_subtype
	,RTRIM(tl.resource_description)
	,tl.request_mode
	,tl.request_status
	,tl.request_session_id
	,tl.request_request_id
	,tl.resource_associated_entity_id
	,CASE 
		WHEN tl.resource_type in ('OBJECT') then OBJECT_NAME( tl.resource_associated_entity_id )
		ELSE object_name(p.object_id)
	END
from 
	sys.dm_tran_locks	tl
	left join
	sys.allocation_units AU ON AU.allocation_unit_id = tl.resource_associated_entity_id	
	LEFT JOIN
	sys.partitions		p on	CASE 
								WHEN tl.resource_type in ('ALLOCATION_UNIT') THEN p.partition_id
									ELSE p.hobt_id
								END = 
								CASE 
								WHEN tl.resource_type in ('ALLOCATION_UNIT') THEN AU.container_id
									ELSE tl.resource_associated_entity_id	
								END
where
		--resource_type <> 'DATABASE'
		--and 
		request_session_id = 64
ORDER BY
		tl.resource_type
	,tl.resource_description

/*
select name,snapshot_isolation_state_desc,is_read_committed_snapshot_on from sys.databases
select * from sys.dm_tran_top_version_generators
select * from sys.dm_tran_active_snapshot_database_transactions
select * from sys.dm_tran_transactions_snapshot 
select * from sys.dm_tran_version_store
*/
--select * from sys.dm_exec_requests




