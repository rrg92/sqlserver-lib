/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Mata toda as sessão que não estejam running.
		na prática, você pode acabar acertando mais do que pensa, pq esse status muda muito rapido.
		Devo ter criado pra algum cenário extremo	
		Também, esse jeito que eu concateno a variável pode não funcionar em certos casos...


*/

DECLARE
	@SQLKill varchar(max);
SET @SQLKill = '';

select
	@SQLKill = @SQLKill +CHAR(10)+CHAR(13)+ 'kill '+cast(s.session_id as varchar(3))
from
	sys.dm_exec_sessions s
	join
	sys.dm_exec_requests r on r.session_id = s.session_id
where
	r.status <> 'running'
	and
	s.session_id > 50
	and
	s.session_id != @@SPID
	
PRINT @SQLKill
--exec(@SQLKill)