/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Como ver os locks em um objeto especifico.
		Atencao: a sys.dm_tran_locks le diretamente de uma estrutura em memoria do SQL...
		E ela pode ser GIGANTE...Usar com muito cuidado isso!

*/

select
	 resource_type
	,resource_subtype
	,db_name(resource_database_id)
	,request_mode
	,request_type
	,request_status
	,request_session_id
	,resource_associated_entity_id
	,es.program_name
	,es.host_name
	,object_name(resource_associated_entity_id,resource_database_id)
	
from
	sys.dm_tran_locks tl
inner join sys.dm_exec_sessions es on es.session_id = tl.request_session_id
where
	--request_type = 'LOCK'
--  resource_type = 'OBJECT'
	resource_database_id = db_id('NomeBanco')
and resource_associated_entity_id = object_id('dbo.NomeTabela')

-- request_session_id in (928)
 
 --and
 --request_status = 'wait'

 