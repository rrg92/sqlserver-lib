/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Traz a lista de proxies usados em cada job!
		Proxy é uma conta do Windows sob o qual o job vai rodar!

*/


--> Quais jobs usam quais proxies?
select J.name,JS.step_name,JS.subsystem,JS.proxy_id,P.name,C.name,C.credential_identity
from msdb..sysjobs J 
JOIN msdb..sysjobsteps JS
	ON JS.job_id = JS.job_id
JOIN msdb..sysproxies P
	ON P.proxy_id = JS.proxy_id
JOIN sys.credentials C
	ON C.credential_id = P.credential_id

-- Se a linha anterior não retornar nada, então não precisa verificar mais nada.


-- Verificar proxies
select * From msdb..sysproxies

-- Lista das credentials 
select * from sys.credentials

-- Verificar proxies criados em quais subsystems
select * from msdb..sysproxysubsystem

-- Verificar quais logins tem permissoa no proxie
select * from msdb..sysproxies

