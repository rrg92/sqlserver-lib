/*#info 

	# author 
		Rodrigo Ribeiro Gomes 

	# detalhes
		Lista a sequencia de backups após os backups de um determinada data.
		Útil para ra´pida conferencia dos backuops feitos e para onde foram feitos.
		Caso queira filtrar banco, etc., add na primeira 

*/

IF OBJECT_ID('tempdb..#BackupBaseInfo') IS NOT NULL
	DROP TABLE #BackupBaseInfo;

--> Aqui vamos carregar o backup_set_id encontrado com o filtro.
-- vamos filtrar somente esses que estao apos esse!
SELECT
	BS.database_name
	,BaseSetId = MAX(BS.backup_set_id)
INTO
	#BackupBaseInfo
FROM
	msdb..backupset BS 
WHERE
	BS.is_copy_only = 0
	AND
	BS.backup_finish_date < '20250101'
	AND
	bs.type = 'D'
GROUP BY
	BS.database_name
OPTION(RECOMPILE)


SELECT
	BS.database_name
	,BS.backup_set_id
	,BS.type
	,BS.backup_finish_date
	,BS.is_copy_only
	,BS.is_snapshot
	,BS.compressed_backup_size
	,BS.backup_size
	,BS.differential_base_guid
	,BS.backup_set_uuid
	,FS.*
	,F.*
FROM
	#BackupBaseInfo BB
	JOIN
	msdb..backupset BS
	ON	 BS.database_name = bb.database_name
	AND BS.backup_set_id >= BB.BaseSetId
	CROSS APPLY (
		SELECT
			NumDevices = COUNT(*)
		FROM
			msdb..backupmediafamily BMF
		WHERE
			BMF.media_set_id = BS.media_set_id
	) FS
	CROSS APPLY (
		SELECT
			bmf.physical_device_name + char(13)+char(10) as 'data()'
		FROM
			msdb..backupmediafamily BMF
		WHERE
			BMF.media_set_id = BS.media_set_id
		ORDER BY
			BMF.media_family_id
		FOR XML PATH(''),TYPE
	) F(devices)
ORDER BY
	BS.database_name
	,BS.backup_set_id