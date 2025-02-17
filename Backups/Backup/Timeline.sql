/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Aqui é mais um script para trazer info de backup de todos os bancos, tamanho, média, etc.
		Provavelmente é um dos promórdios da miha carreira. O script de volumetria é bem melhor que esse.
		MAs, esse é mais simples, então acho justo manter!
*/


DECLARE
	@DataInicial datetime 
	,@DataFinal datetime

	SELECT 
		--> Inicio do ano atual
		@DataInicial = DATEADD(YYYY,DATEDIFF(YYYY,'19000101',CURRENT_TIMESTAMP),'19000101')
		--> Inicio do mes atual ( a query filtra <, o que pegara somente o mes anterior pra tras).
		,@DataFinal = DATEADD(MM,DATEDIFF(MM,'19000101',CURRENT_TIMESTAMP),'19000101')

SELECT
	BTL.MesBackup
	,BTL.banco
	,BTL.type
	,SUM(BTL.BackupSize)	TamanhoBackups
	,COUNT(*)				QtdBackups
	,AVG(BTL.BackupSize)	MediaTamanho
FROM
	(
		SELECT
			DATEADD(MM,DATEDIFF(MM,'19000101',BS.backup_finish_date),'19000101') as MesBackup
			,BS.database_name as banco
			,BS.type
			,BS.compressed_backup_size/1024.00/1024.00 as BackupSize
		FROM
			msdb.dbo.backupset BS
		WHERE
			BS.backup_finish_date >= @DataInicial
			AND
			BS.backup_finish_date <= @DataFinal
	) BTL
GROUP BY
	BTL.MesBackup
	,BTL.banco
	,BTL.type
ORDER BY
	BTL.banco
	,BTL.MesBackup
OPTION(RECOMPILE)