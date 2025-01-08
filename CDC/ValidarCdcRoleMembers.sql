/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Este script checa se alguns usuários estão nos roles do CDC (Change Data Capture).
		Para ter acesso a algumas tabelas do CDC, usuários que não sysadmin, ou db_owner, preciam estar em roles específicas

		ESte script vai em todos os bancos d euma instância que tem CDC habiltiado, e checa se os logins especificados são membros diretos dessas roles.
		
		Caso não sejam, ele gera um script com sqlcmd para inclusão.
		eu não lembro porque não gerei apenas o comando direto para rodar no SSMS. Devia ter algum motivo na épica.
*/

IF OBJECT_ID('tempdb..#RolesCdc') IS NOT NULL
	DROP TABLE #RolesCdc;

CREATE TABLE #RolesCdc(Banco sysname, Login sysname, Usuario sysname,RoleName sysname, IsMembro bit)

IF OBJECT_ID('tempdb..#UsuariosCheck') IS NOT NULL
	DROP TABLE #UsuariosCheck;

CREATE TABLE #UsuariosCheck(NomeLogin sysname);
INSERT INTO #UsuariosCheck VALUES('User1'); --> Ajustar esse INSERT para os usuário que queria validar! Colocar o nome do LOGIN.
INSERT INTO #UsuariosCheck VALUES('User2');

EXEC sp_MSforeachdb '
	
	USE [?];

	IF NOT EXISTS( SELECT * FROM sys.databases WHERE database_id = DB_ID() AND is_cdc_enabled = 1 )
		RETURN;

	DECLARE
		@RoleCdc sysname


	INSERT INTO
		#RolesCdc
	SELECT
		 DB_NAME()
		,L.NomeLogin
		,U.name
		,RCDC.role_name
		,CASE WHEN RM.role_principal_id IS NULL THEN 0 ELSE 1 END as Existe
	FROM
		#UsuariosCheck L
		INNER JOIN
		sys.database_principals U
			ON U.sid = SUSER_SID(L.NomeLogin)
		CROSS JOIN
		(
			select distinct
				role_name 
			FROM
				cdc.change_tables
		) RCDC
		LEFT JOIN
		sys.database_role_members RM
			ON RM.member_principal_id = U.principal_id
			AND rm.role_principal_id = USER_ID(RCDC.role_name)

'


SELECT 
	Banco
	,Login
	,'sqlcmd -S '+@@servername+' -d '+Banco+' -Q "SET NOCOUNT OFF;EXEC sp_addrolemember ''cdc_read'','''+Login+'''" '
	FROM 
#RolesCdc 
	where 
IsMembro = 0