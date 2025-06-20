/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Ler o Xe do ring buffer da sessão SessionWaitsInfo
		
		
*/

IF OBJECT_ID('tempdb..#Events') IS NOT NULL
	DROP TABLE #Events;

SELECT
		SS.name
	,S.address
	,CONVERT(xml,REPLACE(target_data,'<>','')) as TargetData
INTO
	#Events
FROM
	sys.server_event_sessions SS
	LEFT JOIN
	sys.dm_xe_sessions S
		ON S.name = SS.name
	LEFT JOIN 
	sys.dm_xe_session_targets T
		ON T.event_session_address = S.address
WHERE
	SS.name = 'SessionWaitsInfo'

IF OBJECT_ID('tempdb..#RawEvents') IS NOT NULL
	DROP TABLE #RawEvents;

SELECT
	 E.name
	,E.address
	--,EventoXML.query('.')																		as EventXML
	--,EventoXML.value('(event/action[@name = "event_sequence"]/value)[1]','bigint')				as EvtSeq
	,EventoXML.value('event[1]/@name','varchar(500)')											as EventName
	,EventoXML.value('event[1]/@timestamp','datetime2')											as Ts
	,EventoXML.value('(event/action[@name = "session_id"]/value/text())[1]','smallint')			as SPID
	,EventoXML.value('(event/data[@name = "duration"]/value)[1]','bigint')						as Duration
	,EventoXML.value('(event/data[@name = "signal_duration"]/value)[1]','bigint')				as SignalDuration
	,EventoXML.value('(event/data[@name = "opcode"]/value/text())[1]','tinyint')				as OpcOde
	,EventoXML.value('(event/data[@name = "wait_type"]/text/text())[1]','varchar(200)')			as WaitType
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
	WaitType
	,COUNT(*)		OccCount
	,SUM(Duration)	TotalDuration
FROM
	#RawEvents
WHERE		
	Opcode = 1
GROUP BY
	WaitType WITH ROLLUP

