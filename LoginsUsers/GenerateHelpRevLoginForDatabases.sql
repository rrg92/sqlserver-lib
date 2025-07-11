/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Gera o exec da proc sp_help_revlogin para todos os logins que existem em algum banco da instância.
		
		
*/

IF OBJECT_ID('tempdb..#UserBancos') IS NOT NULL
	DROP TABLE #UserBancos;

CREATE TABLE
	#UserBancos( banco sysname, userName sysname, sid varbinary(max) );
	
EXEC sp_MSforeachdb '
	USE [?];
	
	INSERT INTO #UserBancos
	SELECT
	 db_name()
	 ,name
	 ,sid
	FROM
		sys.database_principals DP
'

select distinct SP.NAME,'EXEC sp_help_revlogin '''+SP.name+''' ' from 	#UserBancos ub
inner join
sys.server_principals SP
	ON SP.sid = UB.SID