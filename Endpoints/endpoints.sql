/*#info 
	
	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Script com algumas DMVs que envolvem endpoints.  
		Endpoint é um recurso pouco falado, mas pode ser explorado para melhor controle de acesso via rede. 
		Geralmente só lembra de endpoint ao configurar alwayson ou mirror...
		Mas, tem outros recursos interessantes que dá pra fazer (Ex.: forçar logins por uma porta específica).	

*/


select * from sys.dm_exec_connections
select * from sys.dm_exec_requests
select * from sys.dm_exec_sessions
select * from sys.endpoints
select * from sys.endpoint_webmethods


--Obervandos as sessões e o endpoint usado
select 
	 des.session_id
	,des.login_name
	,des.endpoint_id 
	,endp.endpoint_id
	,endp.name
	,endp.protocol_desc
	,endp.type_desc
	,endp.state_desc
from 
				sys.dm_exec_sessions	des
	INNER JOIN	sys.endpoints			endp	ON	endp.endpoint_id = des.endpoint_id
where
	des.session_id > 50

