/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Consultar o ring buffer com os resultado da sessão XE_CollectProcedureResponseTime
		
		
*/


-- ALTER EVENT SESSION XE_CollectProcedureResponseTime ON SERVER STATE = stop

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
	SS.name = 'XE_CollectProcedureResponseTime'


SELECT
	 E.name
	,E.address
	--,EventoXML.query('.') as exml
	,SWITCHOFFSET(EventoXML.value('(event/@timestamp)[1]','datetimeoffset(3)'),'-03:00')		as EventTs
	,EventoXML.value('event[1]/@name','varchar(500)')										as EventName
	,EventoXML.value('(event/data[@name = "source_database_id"]/value)[1]','int')			as SourceDatabaseID
	,EventoXML.value('(event/data[@name = "object_name"]/value)[1]','sysname')				as ObjectName
	,EventoXML.value('(event/data[@name = "duration"]/value)[1]','bigint')					as Duration
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
     SourceDatabaseID
	,ObjectName
	,AVG(Duration*1.00/1000) as AvgTime
FROM
	#Eventos EV
GROUP BY
	SourceDatabaseID
	,ObjectName
ORDER BY
	AvgTime DESC

