/*#info 
	
	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Retorna os crash dumps que ocorreram na instância e o intervalo, em dias, entre eles.
		Usei muito especialmente com os dumps do sql 2019, onde precisava acompanhar o tempo que ficavm sem o dump após alguma ação.
		Quando saia um CU, eu atualizava o SQL e ficava de olho nessa query para saber se o dumps frequentes paravam de acontecer.
		Eu acompanhava pelos "DaysPassed" para saber o tempo que ficou sem dump e saber se tinhamos um novo recorde, o q poderia indicar correção.

	

*/

select 
	d.*
	,DaysPassed = DATEDIFF(dd,A.creation_time,D.creation_time)
	,a.creation_time
From 
	(
		SELECT
			 d.filename
			,d.creation_time
		FROM
			sys.dm_server_memory_dumps D

		union all

		SELECT
			NULL
			,GETDATE()
	) d
	CROSS APPLY (
		SELECT TOP 1
			*
		FROM
		sys.dm_server_memory_dumps Da
		where
			da.creation_time < D.creation_time
		ORDER BY
			DA.creation_time DESC
	) A
order by
	DaysPassed desc