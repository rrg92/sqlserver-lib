/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Troca a senha dos linked servers que usam um determinado login.
		
*/

DECLARE
	@pass nvarchar(1000)
SET @PASS = ''

select 
	S.name
	,L.local_principal_id
	,L.remote_name
	,L.uses_self_credential
	,REPLACE(
		'EXEC sp_addlinkedsrvlogin @rmtsrvname = N"'+S.name+'", @locallogin = N"'+SUSER_NAME(L.local_principal_id)+'", @useself = N"'+CASE L.uses_self_credential WHEN 1 THEN 'True' ELSE 'False' END+'", @rmtuser = N"'+L.remote_name+'", @rmtpassword = N"'+@pass+'" '
		,'"','''')
from 
	sys.linked_logins  L
	INNER JOIN
	sys.servers S
		ON S.server_id = l.server_id
where 
	remote_name = 'NomeLoginRemoto'

