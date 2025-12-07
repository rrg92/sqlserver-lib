/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Descrição 
		Query para consultar de estatísticas de uso dos arquivos dos bancos;
		Adicionado alguns calculos para obter as médias.
		Provavelmente useu muito para rápida investigação sobre como estava o tempo de resposta (acumulado)
*/



SELECT 
	 DB_NAME( mf.database_id )		as Banco
	,mf.name						as Arquivo
	,vfs.TimeStamp					as Tempo -- Timestamp dos dados obtidos
	,vfs.NumberReads				as L	-- Leituras
	,vfs.BytesRead					as bL	-- Bytes Lidos
	,1.00*vfs.IoStallReadMS/1000	as tmpL -- tempo total ( segundos ) de espera p/ Leitura
	,vfs.NumberWrites				as E	-- EScritas
	,vfs.BytesWritten				as bE	-- bytes Escritos
	,1.00*vfs.IoStallWriteMS/1000	as tmpE -- tempo total ( segundos ) de espera p/ Escrita
	,vfs.BytesOnDisk				as TamArqEstimdo	-- Tamanho do arquivo em bytes (estimado, pois a sys.master_files pode não estar atualizada)
FROM			
					::fn_virtualfilestats(NULL, NULL)	vfs
		INNER JOIN	sys.master_files							mf	on	mf.database_id	= vfs.dbid
																	AND	mf.file_id		= vfs.fileid

SELECT * FROM sys.dm_io_pending_io_requests