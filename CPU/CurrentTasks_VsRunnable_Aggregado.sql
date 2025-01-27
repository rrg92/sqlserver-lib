/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Visão rápida e simples da fila de CPU...
		runnable = pronto pra rodar mas está aguardando vez na CPU!
		Se isso aqui tá próximo de current tasks e não baixa ou sobe e desce, é estranho, significa que alguma coisa travou algum scheduler...
		Pode ser dump, drivers e até bug do sql!
*/

select 
	 SUM(current_tasks_count)
	,SUM(runnable_tasks_count)
from 
	sys.dm_os_schedulers with(nolock)
where
	status = 'VISIBLE ONLINE'