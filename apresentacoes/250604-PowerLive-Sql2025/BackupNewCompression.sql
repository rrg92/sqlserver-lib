-- backup database 
-- https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-compression-sql-server?view=sql-server-ver17#zstd-compression-algorithm-introduced-in-sql-server-2025
-- https://facebook.github.io/zstd
	backup database 
		Traces
	to 
		disk = 'S:\mssql\A25\Traces-ZSTD.bak'
	with
		COMPRESSION (ALGORITHM = ZSTD)
		,init
		,format

	backup database 
		Traces
	to 
		disk = 'S:\mssql\A25\Traces.bak'
	with
		COMPRESSION 
		,init
		,format
	
select compression_algorithm,* 
from msdb..backupset order by backup_finish_date desc