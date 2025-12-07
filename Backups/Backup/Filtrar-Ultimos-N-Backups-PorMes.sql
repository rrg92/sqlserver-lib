/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Permite filtrar os ultimos X backups de cada banco de cada mes.
		Pode ser util se por exemplo, vc quer fazer um expurgo dos seus backup antigos, mantendo apenas o último, ou os 2 ultimos de cada mes.

		Voce pode ajustar o filtro na subquery para somente incluir os backup com o filtro desejado no resultado.
		E na query de fora, pode filtrar o resultado da coluna LastRn... 
		Por exemplo, LastRn = 1, traz somente o ultimo backup de cada mes.
		Se você quiser inverter a ordem (1 sendo o primeiro, e nao o ultimo), altere o order by do row_number, e remova o desc.
*/

select
	*
from 
(
	select
		 AnoMes = convert(varchar(6),backup_finish_date,112)
		,database_name
		,LastRn = row_number() over(partition by convert(varchar(6),backup_finish_date,112),database_name order by backup_finish_date desc )
		,backup_finish_date
		,compressed_backup_size
		,bmf.physical_device_name
	from
		msdb..backupset bs
		inner join -- se seu ambiente faz o split do backup em varios arquivos, pode trocar esse inner join por um cross apply para nao duplicar alguns resultados...
		msdb..backupmediafamily bmf
			on bmf.media_set_id = bs.media_set_id
	where
		type = 'D'
		and
		is_snapshot = 0
		and
		is_copy_only = 0
		-- and
		-- physical_device_name like 'https%container%' --> Exemplo de filtro adicional, incluir apenas backups feitos pra um cotnainer especifico.
) B
where
	LastRn = 1 --> Somente o ultimo backup... Aqui vc poderia colocar um LastRn <= 2 para pegar os 2 ultmios, etc.


	-- exemplos de filtros adicionais:
	-- Aqui você poderia filtrar somente o ultimo antes de um ms especifico... ou todos os backups a partir de um meS!
	-- ( LastRn = 1 and backup_finish_date < '20251201' )
	-- or
	-- backup_finish_date >= '20251201'

order by
	database_name
	,backup_finish_date