/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Consultar os eventos da XE SQLServerErros, que estao em ring buffer.
		
		
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
	SS.name = 'SQLServerErros'


SELECT
	 E.name
	,E.address
	,EventoXML.query('.') as exml
	,EventoXML.value('event[1]/@name','varchar(500)')												as Evento
	,SWITCHOFFSET(EventoXML.value('event[1]/@timestamp','datetimeoffset'),'-03:00')					as Data
	,DB_NAME(EventoXML.value('(event/action[@name = "database_id"]/value)[1]','varchar(max)'))		as Banco
	,EventoXML.value('(event/data[@name = "message"]/value)[1]','varchar(max)')						as ErrorMessage
	,EventoXML.value('(event/action[@name = "sql_text"]/value)[1]','nvarchar(max)')					as Stmt
	,EventoXML.value('(event/action[@name = "session_id"]/value)[1]','nvarchar(max)')				as SessionID
	,EventoXML.value('(event/action[@name = "client_hostname"]/value)[1]','nvarchar(max)')			as HostName
	,EventoXML.value('(event/action[@name = "client_appname"]/value)[1]','nvarchar(max)')			as AppName
	,EventoXML.value('(event/action[@name = "username"]/value)[1]','nvarchar(max)')					as UserName
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

--select * from #TargetData
--select * from #Eventos;
--return;

SELECT
     *
FROM
	#Eventos EV


	--select * from #Eventos where CONVERT(datetime,ContextInfo) = '2014-08-21 01:34:13.607'


