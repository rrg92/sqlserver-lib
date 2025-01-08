/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Este script lista diversas informações relevantes que podem existir em um arquivo de audit. 
		Eu faço uam conversão para hora local (por padrão, a hora no audio é GMT). E trago as colunas mais relevantes (Geralmente).
		Adicionalmente, faço join com algumas dmvs para converter o id das operações em algo mais legível.
		
		Não esqueça de trocar o caminho do audit no parâmetro de fn_get_audit_file
		Lemebre-se que estes arquivos devem estar acessíveis pelo processo da sua instância, isto é, o processo deve conseguir chegar nesse caminho, o que incluir ter as permissões corretas do usuário que roda o serviço.
*/

--> Check Audit file!
SELECT
	A.EventTimeLocal	
	,sequence_number
	,succeeded
	,session_id
	,server_principal_name
	,ACT.name as ActionName
	,database_name
	,object_name
	,statement
	,CONVERT(XML,additional_information) as AdditionaInfo
	,A.class_type
FROM
	(
		SELECT TOP 600
			CONVERT(datetime,SWITCHOFFSET(convert(datetimeoffset,event_time),'-03:00')) EventTimeLocal
			,A.*
		FROM 
			master.sys.fn_get_audit_file('C:\Caminho\Audios\PrefixoArquivo*',NULL,NULL) A --> Mudar nome do arquivo!
		ORDER BY
			1 DESC
	) A
	LEFT JOIN
	sys.dm_audit_class_type_map AM
		ON AM.class_type = A.class_type
	LEFT JOIN
	sys.dm_audit_actions ACT
		ON ACT.action_id = A.action_id
		AND ACT.class_desc = AM.securable_class_desc

--select * from sys.dm_server_audit_status
--select * from sys.dm_xe_sessions where address = 0x000000000738B671
--select * from sys.dm_xe_session_object_columns

--select * from sys.dm_xe_objects where name = 'audit_event'
--select * from sys.dm_xe_packages where guid = 'F235752A-D5C0-4C9A-A735-9C3B6F6E43B1'



