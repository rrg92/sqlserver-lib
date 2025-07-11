/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Gera o comando para add logins em um linked server ,mapeado para um login remoto.
		Especifica na tabela derivada L a lista de logins locais (name) e a lista de remotos com a respectiva senha.
		ATENÇÃO: Não salvar o script com a senha.
		
		
*/

IF OBJECT_ID('tempdb..#Users') IS NOT NULL
	DROP TABLE #Users;


SELECT
	  'EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N''Nome'',@useself=N''False'',@locallogin=N'''+L.name+''',@rmtuser=N'''+L.NomeRemoto+''',@rmtpassword='''+L.pass+''' 
GO'
FROM
	sys.servers S
	CROSS JOIN
	(
		VALUES
			('NomeLocal','NomeRemoto','Senha')
	) L(name,remotename,pass)
	
	
	