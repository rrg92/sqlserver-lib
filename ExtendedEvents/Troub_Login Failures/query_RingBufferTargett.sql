/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Consultar XE do ring bugger, sessão Troub: Login Failures
		
		
*/

IF OBJECT_ID('tempdb..#Eventos') IS NOT NULL
	DROP TABLE #Eventos;

IF OBJECT_ID('tempdb..#TargetData') IS NOT NULL
	DROP TABLE #TargetData;

SELECT
	 SS.name
	,S.address
	,CONVERT(xml,target_data) as TargetData
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
	SS.name = 'Troub: Login Failures'

SELECT
	 TD.name
	,TD.address
	,N.e.value('(action[@name = "event_sequence"]/value)[1]','bigint')		as EvtSeq
	,N.e.value('@name','varchar(500)')								as Evento
	,N.e.value('@timestamp','datetime')								as Data
	,N.e.value('(data[@name = "message"]/value)[1]','varchar(max)')	as ObjectName
	,N.e.value('(action[@name = "sql_text"]/value)[1]','varchar(max)')	as SqlText
	,N.e.value('(action[@name = "username"]/value)[1]','varchar(max)')	as UserName
	,N.e.value('(action[@name = "client_hostname"]/value)[1]','varchar(max)')	as HostName
	,DB_NAME(N.e.value('(action[@name = "database_id"]/value)[1]','varchar(max)'))	as Banco
INTO
	#Eventos
FROM
	#TargetData TD
	CROSS APPLY
	TargetData.nodes('RingBufferTarget/event') N(e)


select * from #TargetData;
select * from #Eventos;


