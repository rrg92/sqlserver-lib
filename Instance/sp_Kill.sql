/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		De tanto que me pediam pra fazer kill, tive a ideia de criar uma proc pra fazer o kill com base em alguns filtros comuns.
		NO caso, foi apenas 1, de um banco específico.
		Quem sabe um dia nao melhoramos isso e adicionamos mais facilidades, hein!?


*/


USE master
GO

IF OBJECT_ID('dbo.sp_Kill') IS NULL
	EXEC('CREATE PROCEDURE dbo.sp_Kill AS SELECT 1 as StubVersion')
GO

ALTER PROCEDURE
	sp_Kill
	(
		@DB sysname = NULL
		,@ShowProgress bit = 1 -- 0 = ExecuteOnly | 1 - Execute and Print | 2 - Print Only
	)
AS
/**
	Kill connections that using based on specific filter.
	Author: Rodrigo Ribeiro Gomes
*/


--DECLARE
--	@ShowProgress bit
--;
--SET @ShowProgress = 1;

------
SET NOCOUNT ON;

DECLARE
	@DBFilter nvarchar(4000)
	,@tsql nvarchar(4000)
;
SET @DBFilter = @DB;


IF @DBFilter IS NULL
	RETURN;

IF OBJECT_ID('tempdb..#DatabaseSessions') IS NOT NULL
	DROP TABLE #DatabaseSessions;

CREATE TABLE #DatabaseSessions(session_id bigint, db_id bigint);

IF OBJECT_ID('master..sysprocesses') IS NOT NULL
	EXEC sp_executesql N'
		INSERT INTO
			#DatabaseSessions
		SELECT
			S.spid
			,S.dbid
		FROM
			master..sysprocesses S
		WHERE
			DB_NAME(S.dbid) like @DBFilter
	',N'@DBFilter nvarchar(4000)',@DBFilter

IF OBJECT_ID('sys.dm_tran_locks') IS NOT NULL
	EXEC sp_executesql N'
		INSERT INTO
			#DatabaseSessions
		SELECT
			TL.request_session_id
			,TL.resource_database_id
		FROM
			sys.dm_tran_locks TL
		WHERE
			DB_NAME(TL.resource_database_id) like @DBFilter
	',N'@DBFilter nvarchar(4000)',@DBFilter



DECLARE 
	curDatabaseSessions CURSOR LOCAL FAST_FORWARD 
FOR
	SELECT DISTINCT
		'KILL '+CONVERT(nvarchar(100),S.session_id)
	FROM 
		#DatabaseSessions S

OPEN curDatabaseSessions;

	FETCH NEXT FROM curDatabaseSessions INTO @tsql;
		
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @ShowProgress >= 1
			RAISERROR('Executando: %s',0,1,@tsql) WITH NOWAIT;

		IF @ShowProgress <= 1
			EXEC(@tsql);

		FETCH NEXT FROM curDatabaseSessions INTO @tsql;
	END

CLOSE curDatabaseSessions;
DEALLOCATE curDatabaseSessions;