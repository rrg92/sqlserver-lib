/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Como listar os bloqueio usando a sp_whoisactive, ordenados por quem está causando!


*/

sp_whoisactive 
	@get_outer_command = 1
	, @delta_interval = 1
	, @find_block_leaders = 1
	,@sort_order = '[blocked_session_count] DESC'
	,@get_plans = 1

	