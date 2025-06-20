/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Ler coleta de waits de performance do arquivo gerado (sessão:XE_PerfomanceDebug)
		
		
*/

-- ALTER EVENT SESSION XE_CollectProcedureResponseTime ON SERVER STATE = stop

IF OBJECT_ID('tempdb..#Eventos') IS NOT NULL
	DROP TABLE #Eventos;

IF OBJECT_ID('tempdb..#TargetData') IS NOT NULL
	DROP TABLE #TargetData;

SELECT
	 IDENTITY(bigint,1,1) as ID
	,T.name
	,T.address
	,CONVERT(xml,REPLACE(target_data,'<>','')) as TargetData
INTO
	#TargetData
FROM
	(
		select 
			 null as name
			,null as address
			,event_data  as target_data
		from 
			sys.fn_xe_file_target_read_file
			(
				'C:\temp\waitsperformance*'
				,'C:\temp\waitsperformance*'
				,null
				,null
			)
	) T



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
			,TargetData.query('.') EventoXML
		FROM
			#TargetData TD
	) E

SELECT
    *
FROM
	#Eventos EV


