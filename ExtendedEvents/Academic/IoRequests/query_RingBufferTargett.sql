/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Consultar o XE gerado pela sessão IoRequests, no ringer buffer target.
		
		
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
	SS.name = 'IoRequests'

--alter event session IoRequests on server state = stop


SELECT
	 E.name
	,E.address
	--,EventoXML.query('.') as exml
	,EventoXML.value('(event/action[@name = "event_sequence"]/value)[1]','bigint')		as EvtSeq
	,EventoXML.value('event[1]/@name','varchar(500)')									as EventName
	,EventoXML.value('event[1]/@timestamp','datetime')									as Ts
	,EventoXML.value('(event/data[@name = "offset"]/value)[1]','bigint')					as Offset
	,EventoXML.value('(event/data[@name = "file_handle"]/value)[1]','varchar(32)')			as FileHandle
	,EventoXML.value('(event/data[@name = "user_data_pointer"]/value)[1]','varchar(32)')	as UserData
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
	 EV.Ts


