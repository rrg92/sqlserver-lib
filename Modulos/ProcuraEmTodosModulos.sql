/*
	Procura um texto em todos os módulos de todos os bancos.	
*/

DECLARE
	 @procura nvarchar(max)
SET  @procura = 'chamados' 

IF OBJECT_ID('tempdb..#resultados') IS NOT NULL
	DROP TABLE #Resultados
CREATE TABLE
	#Resultados ( Banco sysname,NomeObjeto sysname  )

DECLARE
	@SQL varchar(max)
SET @SQL = '
	USE [?];
	
	RAISERROR(''Procurando no banco ?...'',0,0) WITH NOWAIT;
	
	INSERT INTO
		#Resultados( bANCO,NomeObjeto )
	SELECT
		 db_name() COLLATE DATABASE_DEFAULT
		,object_name(  sm.object_id, db_id() ) COLLATE DATABASE_DEFAULT
	FROM
		sys.sql_modules sm
	WHERE
		sm.definition like ''%'+@procura+'%''

	UNION

	SELECT
		 db_name()
		,object_name(  sm.id, db_id() )
	FROM
		sys.syscomments sm
	WHERE
		text like ''%'+@procura+'%''


';



EXEC sp_MSforeachdb @SQL;



RAISERROR('Procurando nos jobs...',0,1) WITH NOWAIT;

set nocount on;
INSERT INTO
	#Resultados( bANCO,NomeObjeto )
SELECT
	'--JOB--' COLLATE DATABASE_DEFAULT
	,J.name COLLATE DATABASE_DEFAULT
FROM
	msdb..sysjobs J
	JOIN
	msdb..sysjobsteps JS
		ON JS.job_id = J.job_id
WHERE
	JS.command like '%'+@procura+'%'
	OR
	J.name like  '%'+@procura+'%'


select *From #Resultados