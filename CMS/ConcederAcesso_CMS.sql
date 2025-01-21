/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Colocar um login nas roles do CMS. 
		Cria o usuário no msdb, se não existe!
*/
DECLARE
	@Login sysname
	,@Role sysname
;

SET @Login = '';
SET @Role = ''; -- ServerGroupReaderRole (Leitura) | ServerGroupAdministratorRole  (Leitura/Criação/Modificação)


--------------------------------------------------------------------------------------------------

IF SUSER_ID(@Login)	IS NULL
BEGIN
	RAISERROR('Login %s não encontrado. Crie usando CREATE LOGIN antes...', 16,1,@Login);
	RETURN;
END

IF @Role NOT IN ('ServerGroupReaderRole','ServerGroupAdministratorRole')
BEGIN
	RAISERROR('Role informada inválido: %s. As Roles válidas são: %s (%s) e %s (%s)', 16,1,@Role,'ServerGroupReaderRole','Leitura','ServerGroupAdministratorRole','Leitura/Criação/Modificação');
	RETURN;
END

DECLARE
	@User sysname
	,@tsql nvarchar(4000)
;


SELECT @User = DP.name FROM msdb.sys.server_principals SP INNER JOIN msdb.sys.database_principals DP ON DP.sid = SP.sid WHERE SP.name = @Login

IF @User IS NULL
BEGIN
	SET @tsql = 'USE msdb; CREATE USER '+QUOTENAME(@Login)+' FROM LOGIN '+QUOTENAME(@Login)+' ;';
	EXEC(@tsql);
END

EXEC msdb..sp_addrolemember @Role,@Login

