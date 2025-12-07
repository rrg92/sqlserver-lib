/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Traz informacoes de uso dos VLFs dos arquivos!
		Já usa a nova DMV que apareceu  partir do 2017 e 2016 sp2.

		obtem informacoes apenas do banco atual!
*/

if object_id('tempdb..#LogInfo') is not null drop table #LogInfo; 
	CREATE TABLE #LogInfo(fileid smallint,filesize bigint,StartOffset bigint
							,FSeqNo bigint, Status int, Parity int, CreateLSN varchar(1000))
	

	IF OBJECT_ID('sys.dm_db_log_info') IS NOT NULL
		insert into  #LogInfo
		SELECT file_id,vlf_size_mb*1024*1024,vlf_begin_offset,vlf_sequence_number,vlf_status,vlf_parity,vlf_create_lsn FROM sys.dm_db_log_info(null)
	ELSE
		insert into  #LogInfo exec('DBCC LOGINFO');


	SELECT
		li.*
		,Size = li.filesize/1024.00/1024.00
		,ExpectedNext = N.StartOffset
		,shr.*
	FROM
		#LogInfo li
		outer apply
		(
			--> traz qual o proximo vlf
			select top 1
				* 
			from 
				#LogInfo LIN
			where
				lin.fileid = li.fileid
				AND
				LIn.StartOffset > li.StartOffset
			order by
				lin.StartOffset
		) n
		outer apply
		(
			--> conta quantos vls tem apos este atual!
			select
				  NextsCount = count(*)
				 ,NextsTotalMB = sum(lin.filesize)/1024.00/1024.00
			from 
				#LogInfo LIN
			where
				lin.fileid = li.fileid
				AND
				LIn.StartOffset > li.StartOffset
		) shr
	ORDER BY
		li.FSeqNo DESC, li.StartOffset desc
