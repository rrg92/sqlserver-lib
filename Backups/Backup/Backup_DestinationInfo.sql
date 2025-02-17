/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Esse é uma das primeiras versões d eum script para trazer a sequencia de backup e logs pra um restore fácil.
		Tenho um melhor (pasta restores). Mas fica aqui pra ideias!
*/


select database_name,type,begins_log_chain,backup_finish_date,is_copy_only,has_incomplete_metadata,d.recovery_model_desc,bmf.physical_device_name,o.*
,backup_size

from msdb..backupset bs
inner join
sys.databases d
	on d.name = bs.database_name
inner join
msdb..backupmediafamily bmf
	on bmf.media_set_id = bs.media_set_id
outer apply(select top 1 bs2.backup_finish_date as LastFull from msdb..backupset bs2 where bs2.database_name = bs.database_name and bs2.type = 'D'
		order by bs2.backup_finish_date desc
	) o
where
	d.name = 'master' and type = 'L'		--> ajustar filtros
order by
	bs.backup_finish_date desc

