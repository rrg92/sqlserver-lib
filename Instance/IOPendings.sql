/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Lista todos os io que estão pendings.
		Você quer ver isso vazio ou com números muito baixo o máximo de tempo possível.


*/

select 
	r.io_pending_ms_ticks
	,r.io_type
	,r.io_pending
	,db_name(vfs.database_id)
	,mf.physical_name 
from 
	sys.dm_io_pending_io_requests r 
	left join 
	sys.dm_io_virtual_file_stats(null,null) vfs on vfs.file_handle = r.io_handle
	left join
	sys.master_files mf
		on mf.database_id = vfs.database_id
		and mf.file_id = vfs.file_id
ORDER BY
	r.io_pending_ms_ticks desc