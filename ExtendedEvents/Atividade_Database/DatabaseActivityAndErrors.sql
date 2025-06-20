/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Consultar os eventos do ring buffer gerado pela sessão DatabaseActivityAndErrors 
		
		
*/

IF OBJECT_ID('tempdb..#Eventos') IS NOT NULL
	DROP TABLE #Eventos;

IF OBJECT_ID('tempdb..#TargetData') IS NOT NULL
	DROP TABLE #TargetData;
	
SELECT
	 IDENTITY(bigint,1,1) as ID
	,SS.name
	,S.address
	,CONVERT(xml,REPLACE(target_data,'<>','')) as TargetData
INTO
	#TargetData
FROM
	sys.server_event_sessions SS
	LEFT JOIN
	sys.dm_xe_sessions S
		ON S.name = SS.name
	LEFT JOIN 
	sys.dm_xe_session_targets T
		ON T.event_session_address = S.address
WHERE
	SS.name = 'DatabaseActivityAndErrors'

	
SELECT
	 E.name
	,E.address
	--,EventoXML.query('.')																		as EventoXML
	,EventoXML.value('(event/action[@name = "event_sequence"]/value)[1]','bigint')				as EvtSeq
	,EventoXML.value('event[1]/@name','varchar(500)')											as Evento
	,EventoXML.value('event[1]/@timestamp','datetime')											as Data
	,EventoXML.value('(event/action[@name = "session_id"]/value/text())[1]','smallint')			as SPID
	,EventoXML.value('(event/action[@name = "database_name"]/value/text())[1]','sysname')		as Banco
	,EventoXML.value('(event/data[@name = "batch_text"]/value/text())[1]','nvarchar(4000)')		as BatchText
	,EventoXML.value('(event/data[@name = "statement"]/value)[1]','nvarchar(max)')				as Stmt
	,EventoXML.value('(event/data[@name = "object_name"]/value)[1]','sysname')					as ObjectName
	,EventoXML.value('(event/data[@name = "duration"]/value)[1]','bigint')						as Duration
	,EventoXML.value('(event/data[@name = "message"]/value)[1]','nvarchar(1000)')				as ErrorMessage
	,EventoXML.value('(event/action[@name = "sql_text"]/value)[1]','nvarchar(max)')				as SQLText
INTO
	#Eventos
FROM
	(
		SELECT
			 TD.name
			,TD.address
			,EventXML.query('.') EventoXML
		FROM
			#TargetData TD
			CROSS APPLY
			TargetData.nodes('RingBufferTarget/event') N(EventXML)
	) E


SELECT
    *
FROM
	#Eventos EV
ORDER BY
	EvtSeq

	

