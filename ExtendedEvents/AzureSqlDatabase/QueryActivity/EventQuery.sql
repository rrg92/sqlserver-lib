/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Criei para um script rápido que roda no Azure SQL Database, para consultar uma sessão com as queries executadas.
		Troque TraceQueries pelo nome da sessão desejada.
		
		
*/
IF OBJECT_ID('tempdb..#Events') IS NOT NULL
	DROP TABLE #Events;

SELECT
	S.name
	,S.address
	,CONVERT(xml,REPLACE(target_data,'<>','')) as TargetData
INTO
	#Events
FROM
	sys.dm_xe_database_session_targets T
	JOIN
	sys.dm_xe_database_sessions S
		ON S.address = T.event_session_address
WHERE
	S.name = 'TraceQueries'

IF OBJECT_ID('tempdb..#RawEvents') IS NOT NULL
	DROP TABLE #RawEvents;

SELECT
	 Ts			= DATEADD(HH,-3,EventoXML.value('event[1]/@timestamp','datetime2'))
	,EventName	= EventoXML.value('event[1]/@name','varchar(500)')
	 --E.name
	--,E.address
	--,EventoXML.query('.')																		as EventXML
	--,EventoXML.value('(event/action[@name = "event_sequence"]/value)[1]','bigint')				as EvtSeq
	,EventoXML.value('(event/action[@name = "session_id"]/value/text())[1]','smallint')			as SPID
	,ClientHost		= EventoXML.value('(event/action[@name = "client_hostname"]/value/text())[1]','nvarchar(1000)')
	,ClientAppName	= EventoXML.value('(event/action[@name = "client_app_name"]/value/text())[1]','nvarchar(1000)')
	,SqlText = COALESCE(
		EventoXML.value('(event/data[@name = "batch_text"]/value/text())[1]','nvarchar(max)')
		,EventoXML.value('(event/data[@name = "statement"]/value/text())[1]','nvarchar(max)')
	)
INTO
	#RawEvents
FROM
	(
		SELECT
			 TD.name
			,TD.address
			,EventXML.query('.') EventoXML
		FROM
			(
				SELECT * FROM #Events
			) TD
			CROSS APPLY
			TargetData.nodes('RingBufferTarget/event') N(EventXML)
	) E


SELECT
	*
FROM
	#RawEvents
