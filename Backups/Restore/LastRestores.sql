/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Lista informações dos últimos restores feitos.
		O padrão que deixei procura por restores feitos nos últimos 7 dias!
		O script somente pega o último restore feito de cada banco.
		
		Ajuste o filtro em 'filtro de data', para delimitar.
		Você pode comentar, caso queria considerar tudo!

*/

IF OBJECT_ID('tempdb..#LastRestores') is not null
	DROP TABLE #LastRestores


SELECT
	*
INTO
	#LastRestores
from (
	SELECT 
		Rn = ROW_NUMBER() OVER(PARTITION BY RH.destination_database_name,RH.restore_type ORDER BY RH.restore_date DESC)
		,DbName = rh.destination_database_name
		,rh.backup_set_id
		,rh.restore_type
		,RH.restore_date
		,RH.recovery
	FROM
		msdb..restorehistory RH
	WHERE
		RH.restore_date >= DATEADD(dd,-7,GETDATE()) --> filtro de data
) R
WHERE
	R.Rn  =1

SELECT
	LR.DbName
	,LR.restore_type
	,DataRestore	= LR.restore_date
	,HorasRestore	= 'Há '+convert(varchar(100),DATEDIFF(HH,LR.restore_date,GETDATE()))+'h'
	,NoRecov		= ~LR.recovery
	,DataBackup		= LB.backup_finish_date
	,OrigemBackup	= LB.server_name
	,BackupSizeMB	= CONVERT(decimal(30,2),LB.compressed_backup_size/1024.00/1024)
	,D.database_id
	,D.state_desc
	,RestoreFile = SUBSTRING(LB.RestoreFile,2,999999)
FROM	
	#LastRestores LR
	OUTER APPLY
	(
		SELECT
			*
			,RestoreFile = (
				SELECT 
					','+BMF.physical_device_name 
				FROM msdb..backupmediafamily BMF
				WHERE BMF.media_set_id = BS.media_set_id
				FOR XML PATH('')
			)	
		FROM
			msdb..backupset BS
		WHERE
			BS.backup_set_id = LR.backup_set_id
	) LB
	LEFT JOIN
	sys.databases D
		ON D.name = LR.DbName
ORDER BY
	LR.DbName
	,LR.restore_type
	,LR.restore_date