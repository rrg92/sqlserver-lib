/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Procedure que criei há muitos anos quando tive a necessidade de mapear as permissoes efetivas de um usuaario no sql server...
		O permisionamento no sql server é compelxo, tem hierarquias (ver arquivo: ../expand_permission_hierarchy.sql)
		Por exemplo, um DENY CONTROL pode causar um DENY de select... 
		Soma isso com roles, grupos, etc... 
		No final, os usuarios podem ter mais permissão do que deveriam...
		Essa proc foi uma tentativa de tentar ter uma visão melhor...
		Ultima vez que mexi foi há quase 10 anos... pode precisar de um update, que eu ainda não fiz... 
		
		Mas vou deixar ai caso alguem queirar brincar e contribuir mais.
		

*/

USE master
GO

IF OBJECT_ID('dbo.sp_WhoIsAuthorized') IS NULL EXEC('CREATE PROCEDURE sp_WhoIsAuthorized AS SELECT 1 StubVersion');
GO


ALTER PROCEDURE dbo.sp_WhoIsAuthorized
(
	 @Filter nvarchar(2000)				= NULL
	,@OrderBy nvarchar(1000)			= NULL
	,@ColumnsList nvarchar(1000)		= NULL
	,@ShowDefaultRoles 	INT				= 0
	,@DetailsLevel int					= 2
	,@MembershipLevel tinyint			= 2
	,@CoverDeniedOnly bit				= 1
	,@ProgressLevel smallint 			= 5
	,@DisableTokenCheck bit 			= 0
	,@WarningsAsText bit				= 0
	,@help varchar(10) 					= NULL
	,@DebuggingTable sysname			= NULL
	,@DebugExtra nvarchar(4000)			= NULL
)
AS
	SET NOCOUNT ON; 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET QUOTED_IDENTIFIER ON;
	SET ANSI_PADDING ON;
	SET CONCAT_NULL_YIELDS_NULL ON;
	SET ANSI_WARNINGS ON;
	SET NUMERIC_ROUNDABORT OFF;
	SET ARITHABORT ON;

	-- VARIABLE STORE
	DECLARE
		@dynQuery nvarchar(max)
		,@dynQueryFinal nvarchar(max)
		,@CurrentLogin int
		,@contextChanged bit
		,@OriginalLogin sysname
		,@CurrentRunningDB int
		,@DbName sysname
		,@FilterSeparator nchar(1)
		,@FilterEscape nchar(1)
		,@Filters XML
		,@DocDelimiters nvarchar(20)
		,@Doc nvarchar(max)
		,@LineChar nvarchar(2)
		,@finalDocQuery nvarchar(max)
		,@LoginName sysname
		,@WarningText nvarchar(4000)
		,@FinalDataSource sysname
		,@DefaultOrderBy nvarchar(1000)
		,@DefaultColumnsList nvarchar(1000)
		,@SqlVersion int
		,@TopCoverings int
	;

	-- TABLES VARIABLES STORE
	DECLARE @LoginsForExpand TABLE(ID int IDENTITY, winLogin sysname COLLATE Latin1_General_CI_AI);
	DECLARE @DatabasesToRun TABLE(ID int IDENTITY, name sysname);
	DECLARE @FilterSourceMap TABLE(sourceName varchar(500) COLLATE Latin1_General_CI_AI, filterType varchar(500) COLLATE Latin1_General_CI_AI);

	-- TEMPORARY TABLE STORE
	IF OBJECT_ID('tempdb..#Doc') IS NOT NULL
		DROP TABLE #Doc;

	IF OBJECT_ID('tempdb..#Warnings') IS NOT NULL
		DROP TABLE #Warnings;
	CREATE TABLE #Warnings( id int not null identity, message varchar(8000));

	IF OBJECT_ID('tempdb..#FixedRolePermissions') IS NOT NULL
		DROP TABLE #FixedRolePermissions;

	IF OBJECT_ID('tempdb..#FixedServerRolePermissions') IS NOT NULL
		DROP TABLE #FixedServerRolePermissions;

	IF OBJECT_ID('tempdb..#RawPermissions') IS NOT NULL
		DROP TABLE #RawPermissions;

	IF OBJECT_ID('tempdb..#FilterTable') IS NOT NULL
		DROP TABLE #FilterTable;

	IF OBJECT_ID('tempdb..#FilteredPrincipals') IS NOT NULL
		DROP TABLE #FilteredPrincipals;

	IF OBJECT_ID('tempdb..#LoginTokenResults') IS NOT NULL
		DROP TABLE #LoginTokenResults;
	CREATE TABLE #LoginTokenResults(winLogin sysname COLLATE Latin1_General_CI_AI, groupName sysname COLLATE Latin1_General_CI_AI);

	IF OBJECT_ID('tempdb..#PrincipalsPermissions') IS NOT NULL
		DROP TABLE #PrincipalsPermissions;

	IF OBJECT_ID('tempdb..#ExpandedChecks') IS NOT NULL
		DROP TABLE #ExpandedChecks;

	IF OBJECT_ID('tempdb..#CoveringPermissions') IS NOT NULL
		DROP TABLE #CoveringPermissions;

	IF OBJECT_ID('tempdb..#FilteredPermissions') IS NOT NULL
		DROP TABLE #FilteredPermissions;

	IF OBJECT_ID('tempdb..#FilteredObjects') IS NOT NULL
		DROP TABLE #FilteredObjects

	IF OBJECT_ID('tempdb..#PrincipalEffective') IS NOT NULL
		DROP TABLE #PrincipalEffective

	IF OBJECT_ID('tempdb..#DebuggingInfo') IS NOT NULL
		DROP TABLE #DebuggingInfo;
	CREATE TABLE #DebuggingInfo(id varchar(100),data XML);


	IF @ProgressLevel >= 3 RAISERROR('sp_WhoIsAuthorized will work!',0,1) WITH NOWAIT;

	SELECT 
		@SqlVersion = CONVERT(int,LEFT(SqlVersion,CHARINDEX('.',SqlVersion)-1)) 
	FROM 
		(SELECT CONVERT(varchar(10),SERVERPROPERTY('ProductVersion')) AS SqlVersion) V


	-- This is help part. After show help, script exits.
	IF @help IS NOT NULL
	BEGIN
		IF @ProgressLevel >= 5 RAISERROR('Showing help...',0,1) WITH NOWAIT;

		SET @DocDelimiters = '*DOC:<LANG>';

		IF ISNULL(@help,'') NOT IN ('EN-US','PT-BR')
		BEGIN
			IF @ProgressLevel >= 3 RAISERROR('Help language ~%s~ not found . Default will be used',0,1,@help) WITH NOWAIT;
			SET @help = 'EN-US';
		END

		SET @DocDelimiters = REPLACE(@DocDelimiters,'<LANG>',@help);
		--> Find initial DOC part...
		SET @LineChar = NCHAR(13)+NCHAR(10);

		;WITH ForEachLine AS
		(
			SELECT
				L.CurrentLine
				,L.StartLine
				,L.EndLine
				,SUBSTRING(L.FullDoc,L.StartLine,L.EndLine) as LineString
				,L.FullDoc
			FROM
				(
					SELECT
						1 as CurrentLine
						,CONVERT(bigint,0) StartLine
						,CONVERT(bigint,CHARINDEX(@LineChar,DOC.FullDoc)) EndLine
						,DOC.FullDoc
					FROM
						(
							SELECT
								CASE
									WHEN D.DocStart != 0 AND D.DocEnd != 0 THEN SUBSTRING(D.ThisText,D.DocStart,D.DocEnd-D.DocStart)
									ELSE NULL
								END FullDoc
							FROM
								(
									SELECT 
										ST.text ThisText
										,CHARINDEX( @DocDelimiters, ST.text ) as DocStart
										,CHARINDEX( @DocDelimiters, ST.text , CHARINDEX( @DocDelimiters, ST.text )+1 ) as DocEnd
									FROM
										sys.dm_exec_requests R
										CROSS APPLY
										sys.dm_exec_sql_text(R.sql_handle) ST
									WHERE
										R.session_id = @@SPID
								) D
						) DOC
				) L

			UNION ALL

			SELECT
				L.CurrentLine
				,L.StartLine
				,L.EndLine
				,SUBSTRING(L.FullDoc,L.StartLine,L.EndLine-L.StartLine)
				,L.FullDoc
			FROM
				(
					SELECT
						L.CurrentLine + 1 as CurrentLine
						,L.EndLine+len(@LineChar) as StartLine
						,CHARINDEX(NCHAR(13)+NCHAR(10),L.FullDoc,L.EndLine+len(@LineChar)) as EndLine
						,L.FullDoc
					FROM
						ForEachLine L
				) L
			WHERE
				L.EndLine != 0
		)
		SELECT
			quotename(FEL.LineString) as LineString
			,CASE	
				WHEN FEL.TrimmedLine LIKE '.%' THEN STUFF(FEL.LineString,1,1,NULL)
				--WHEN FEL.TrimmedLine LIKE '@%' THEN REPLICATE(NCHAR(9),4)+FEL.LineString
				--WHEN FEL.TrimmedLine LIKE '\[%\]' ESCAPE '\' THEN REPLICATE(NCHAR(9),4)+FEL.LineString
				ELSE ''
			END TITLE
			,CASE	
				WHEN FEL.TrimmedLine LIKE '[.]%' ESCAPE '\' THEN ''
				ELSE FEL.LineString
			END TXT
		INTO
			#Doc
		FROM
			(
				SELECT
					FEL.*
					,REPLACE(LTRIM(RTRIM(FEL.LineString)),NCHAR(9),N'') as TrimmedLine
				FROM
					ForEachLine FEL
			) FEL
		WHERE
			FEL.CurrentLine > 1
		OPTION(MAXRECURSION 0)
	
		SET @finalDocQuery = N'
			SELECT
				 TITLE ['+REPLICATE('=',( SELECT CONVERT(varchar(10),MAX( CASE WHEN LEN(TITLE) > 128 THEN 128 ELSE LEN(TITLE) END)) FROM #DOC ))+']
				,TXT ['+REPLICATE('=',( SELECT CONVERT(varchar(10),MAX( CASE WHEN LEN(TXT) > 128 THEN 128 ELSE LEN(TXT) END)) FROM #DOC ))+']
			FROM
				#Doc
		'

		IF NOT EXISTS(SELECT * FROM #Doc)
		BEGIN
			SELECT 'No help found with language '+@help 
			RETURN;
		END
	
		EXEC sp_executesql @finalDocQuery;

		RETURN;
	END

	--> Initializaing some important variables and validating paramters...
		SET @DefaultOrderBy = NULL;
		SET @DefaultColumnsList = NULL;

		IF @MembershipLevel IS NULL OR @MembershipLevel NOT IN (0,1,2,3)
			SET @MembershipLevel = 2;

	-- First, lets copy structure...
		SELECT TOP 0 * INTO #FixedRolePermissions FROM  sys.database_permissions;
		SELECT TOP 0 * INTO #FixedServerRolePermissions FROM sys.server_permissions;

	-- Databaserole db_accessadmin
		IF @ProgressLevel >= 5 RAISERROR('Inserting fixed database role permisions',0,1) WITH NOWAIT;
		INSERT INTO #FixedRolePermissions 
		SELECT 0,'DATABASE',0,0,USER_ID('db_accessadmin'),1,'','ALTER ANY USER','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_accessadmin'),1,'','CREATE SCHEMA','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_accessadmin'),1,'','CONNECT','W','GRANT_WITH_GRANT_OPTION'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_backupoperator'),1,'','BACKUP DATABASE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_backupoperator'),1,'','BACKUP LOG','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_backupoperator'),1,'','CHECKPOINT','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_datareader'),1,'','SELECT','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_datawriter'),1,'','DELETE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_datawriter'),1,'','INSERT','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_datawriter'),1,'','UPDATE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY ASSEMBLY','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY ASYMMETRIC KEY','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY CERTIFICATE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY CONTRACT','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY DATABASE DDL TRIGGER','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY DATABASE EVENT','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','NOTIFICATION','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY DATASPACE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY FULLTEXT CATALOG','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY MESSAGE TYPE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY REMOTE SERVICE BINDING','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY ROUTE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY SCHEMA','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY SERVICE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','ALTER ANY SYMMETRIC KEY','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CHECKPOINT','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE AGGREGATE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE DEFAULT','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE FUNCTION','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE PROCEDURE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE QUEUE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE RULE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE SYNONYM','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE TABLE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE TYPE','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE VIEW','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','CREATE XML SCHEMA COLLECTION','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_ddladmin'),1,'','REFERENCES','G','GRANT'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_denydatareader'),1,'','SELECT','D','DENY'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_denydatawriter'),1,'','DELETE','D','DENY'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_denydatawriter'),1,'','INSERT','D','DENY'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_denydatawriter'),1,'','UPDATE','D','DENY'
		UNION ALL SELECT 0,'DATABASE',0,0,USER_ID('db_owner'),1,'','CONTROL','G','GRANT'

		-- Inserting server role permissions: https://technet.microsoft.com/en-us/library/ms175892%28v=sql.105%29.aspx
		IF @ProgressLevel >= 5 RAISERROR('Inserting fixed server role permissions',0,1) WITH NOWAIT;
		INSERT INTO #FixedServerRolePermissions 
		SELECT 100,'SERVER',0,0,SUSER_ID('bulkadmin'),1,'','ADMINISTER BULK OPERATIONS','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('dbcreator'),1,'','CREATE ANY DATABASE','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('diskadmin'),1,'','ALTER RESOURCES','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('processadmin'),1,'','ALTER ANY CONNECTION','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('processadmin'),1,'','ALTER SERVER STATE','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('securityadmin'),1,'','ALTER ANY LOGIN','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('serveradmin'),1,'','ALTER ANY ENDPOINT','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('serveradmin'),1,'','ALTER RESOURCES','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('serveradmin'),1,'','ALTER SERVER STATE','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('serveradmin'),1,'','ALTER SETTINGS','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('serveradmin'),1,'','SHUTDOWN','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('serveradmin'),1,'','VIEW SERVER STATE','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('setupadmin'),1,'','ALTER ANY LINKED SERVER','G','GRANT'
		UNION ALL SELECT 100,'SERVER',0,0,SUSER_ID('sysadmin'),1,'','CONTROL SERVER','G','GRANT'

	--> Setting filtering defaults and user provided values...
		IF @ProgressLevel >= 5 RAISERROR('Determine filtering settings...',0,1) WITH NOWAIT;

		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
							SELECT 'FIXED_ROLES',(SELECT * FROM #FixedRolePermissions FOR XML PATH('Permission'),ROOT('FixedRolePermissions'),TYPE)
				UNION ALL	SELECT 'DB_ROLES',(SELECT * FROM #FixedServerRolePermissions FOR XML PATH('Permission'),ROOT('FixedServerRolePermissions'),TYPE)
	

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END

		CREATE TABLE #FilterTable( 
				[Filter] nvarchar(max) COLLATE Latin1_General_CI_AI
				,[FilterType] varchar(100) COLLATE Latin1_General_CI_AI 
				,isNot bit
			);

		INSERT INTO @FilterSourceMap
					  SELECT '@DB','DATABASE'
			UNION ALL SELECT '@U','PRINCIPAL'
			UNION ALL SELECT '@P','SERVER_PERMISSION'
			UNION ALL SELECT '@P','DATABASE_PERMISSION'
			UNION ALL SELECT '@PS','SERVER_PERMISSION'
			UNION ALL SELECT '@PD','DATABASE_PERMISSION'
			UNION ALL SELECT '@S','SECURABLE'
		
		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'FILTER_SOURCE_MAP',(SELECT * FROM @FilterSourceMap FOR XML PATH('Map'),ROOT('FilterSourceMap'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END

		--Filter syntax: 'SOURCE:Value'
		SET @FilterSeparator = N' ';
		SET @FilterEscape = N'\'
		SET @Filter = REPLACE(@Filter,NCHAR(13)+NCHAR(10),@FilterSeparator)
		SET @Filters  = (SELECT @Filter as 'complex' FOR XML PATH(''),ROOT('filters'))
	
		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'COMPLEX_FILTER',@Filters

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END

		IF @ProgressLevel >= 5 
			RAISERROR('Extracting filter expressions...',0,1) WITH NOWAIT;

		;WITH Filtering AS
		(
			SELECT
				F.FilterStart
				,F.FilterEnd
				,F.OriginalString
				,CONVERT(nvarchar(2000),CASE
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '\[%\]:%' ESCAPE '\' THEN  RIGHT(F.FilterExpr,LEN(F.FilterExpr)-CHARINDEX(':',F.FilterExpr))
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '@%:%' ESCAPE '\' THEN  RIGHT(F.FilterExpr,LEN(F.FilterExpr)-CHARINDEX(':',F.FilterExpr))
					ELSE F.FilterExpr
				END) FilterExpr
				,CONVERT(varchar(500),CASE 
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '\[%\]:%' ESCAPE '\' THEN 'COLUMN:'+LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr)-1)
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '@%:%' THEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr)-1)
					ELSE F.FilterSrc
				END) as FilterSrc
				
				--. This part replaces a ESCAPE ESCAPE by a SEPARATOR because SEPARATOR never will be on Expression.
					-- Then we check if replaced string ends with a ESCAPE. If yes, will set this column to 1.
					-- This flag will be used to determine if a separator WAS escaped.
				,CASE RIGHT(REPLACE(F.FilterExpr,REPLICATE(@FilterEscape,2),@FilterSeparator),1)
					WHEN '\' THEN 1
					ELSE 0
				END as EscapeSeparator
			FROM
			(
				SELECT
					F.*
					,CONVERT(nvarchar(2000),SUBSTRING(F.OriginalString,FilterStart,FilterEnd-FilterStart)) FilterExpr
				FROM
					(
						SELECT
							 CONVERT(int,0) as FilterStart
							,CHARINDEX(@FilterSeparator,F.OriginalString) as FilterEnd
							,F.OriginalString
							,F.FilterSrc
						FROM
							(
								SELECT 
									F.data.value('data(.)','nvarchar(2000)')+@FilterSeparator	COLLATE Latin1_General_CI_AS OriginalString
									,'@U'														COLLATE Latin1_General_CI_AS FilterSrc
								FROM 
									@filters.nodes('filters/child::*') F(data)
							) F
					) F
			) F

			UNION ALL
		
			SELECT
				F.FilterStart
				,F.FilterEnd
				,F.OriginalString
				,CONVERT(nvarchar(2000),CASE
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '\[%\]:%' ESCAPE '\' THEN  RIGHT(F.FilterExpr,LEN(F.FilterExpr)-CHARINDEX(':',F.FilterExpr))
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '@%:%' ESCAPE '\' THEN  RIGHT(F.FilterExpr,LEN(F.FilterExpr)-CHARINDEX(':',F.FilterExpr))
					ELSE F.FilterExpr
				END) FilterExpr
				,CONVERT(varchar(500),CASE 
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '\[%\]:%' ESCAPE '\' THEN 'COLUMN:'+LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr)-1)
					WHEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr))  LIKE '@%:%' THEN LEFT(F.FilterExpr,CHARINDEX(':',F.FilterExpr)-1)
					ELSE F.FilterSrc
				END) as FilterSrc
				,CASE RIGHT(REPLACE(F.FilterExpr,REPLICATE(@FilterEscape,2),@FilterSeparator),1)
					WHEN '\' THEN 1
					ELSE 0
				END as EscapeSeparator
			FROM
			(
				SELECT
					F.*
					,CONVERT(nvarchar(2000),SUBSTRING(F.OriginalString,FilterStart,FilterEnd-FilterStart)) FilterExpr
				FROM
					(
						SELECT
							--> If last EscapeSeparator flag was set to 1, then the separator was escaped.
								-- When separator is escaped, we use the same start of last iteration.
								-- This allows get entire string since initial position, before separator.
							CASE F.EscapeSeparator
								 WHEN 1 THEN F.FilterStart 
								 ELSE F.FilterEnd + 1 
							END as FilterStart
							,CHARINDEX(@FilterSeparator,F.OriginalString,F.FilterEnd + 1) as FilterEnd
							,F.OriginalString
							,F.FilterSrc
						FROM
							Filtering F
					) F
				WHERE
					F.FilterEnd	 != 0
			) F
		)		
		INSERT INTO	
			#FilterTable
		SELECT DISTINCT
			CASE LEFT(F.Filter,1)
				WHEN '-' THEN STUFF(F.Filter,1,1,'')
				ELSE F.Filter
			END
			,ISNULL(F.FilterType,F.FilterSrc) AS FilterType
			,CASE LEFT(F.Filter,1)
				WHEN '-' THEN 1
				ELSE 0
			END
		FROM	
			(
				SELECT
					 --> This nested	 REPLACES change escapes into literals.
					  REPLACE( --. This REPLACE A ESCAPE+ESCAPE by a literal ESCAPE.
							REPLACE( --> This replace a ESCAPE+SEPARATOR by a literal SEPERATOR.
								F.FilterExpr,@FilterEscape+@FilterSeparator,@FilterSeparator
								)
						,REPLICATE(@FilterEscape,2),@FilterEscape
					  ) AS Filter
					 ,FSM.filterType AS FilterType
					 ,F.FilterSrc
				FROM
					Filtering F
					LEFT JOIN
					@FilterSourceMap FSM
						ON F.FilterSrc  LIKE FSM.sourceName ESCAPE '\'
				WHERE
					F.EscapeSeparator = 0
			) F
		WHERE
			CASE LEFT(F.Filter,1)
				WHEN '-' THEN STUFF(F.Filter,1,1,'')
				ELSE F.Filter
			END like '_%'
		OPTION(MAXRECURSION 0)
	

		--> If not exists any filter for database...
		IF NOT EXISTS(SELECT * FROM #FilterTable FT WHERE FT.FilterType = 'DATABASE')
			INSERT INTO #FilterTable VALUES(DB_NAME(),'DATABASE',0);

		--> If not exists any filter for database...
		IF NOT EXISTS(SELECT * FROM #FilterTable FT WHERE FT.FilterType = 'PRINCIPAL')
			INSERT INTO #FilterTable VALUES(SUSER_NAME(),'PRINCIPAL',0);

		IF NOT EXISTS(SELECT * FROM #FilterTable FT WHERE FT.FilterType = 'SERVER_PERMISSION')
			INSERT INTO #FilterTable VALUES('%','SERVER_PERMISSION',0);

		IF NOT EXISTS(SELECT * FROM #FilterTable FT WHERE FT.FilterType = 'DATABASE_PERMISSION')
			INSERT INTO #FilterTable VALUES('%','DATABASE_PERMISSION',0);

		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'FILTER_TABLE',(SELECT * FROM #FilterTable FOR XML PATH('FilterExpression'),ROOT('FilterTable'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END

		END

		IF @ProgressLevel >= 5
		BEGIN
			SET @dynQuery  = '';
		
			SELECT 
				@dynQuery = @dynQuery + 
					'RAISERROR('+
						REPLACE(REPLACE(
							QUOTENAME(NCHAR(9)+'Type: '+FT.FilterType+' Filter: '+FT.Filter+ISNULL(CASE isNot WHEN 1 THEN '(NOT)' END,''),'"')+',0,1) WITH NOWAIT;'
							,'%','%%'
						)
							,'''','"'	
						)
			FROM 
				#FilterTable FT;
			SET @dynQuery = REPLACE(@dynQuery,'"','''');

			RAISERROR('-- FILTER TABLE --',0,1) WITH NOWAIT;
			EXEC sp_executesql @dynQuery;
		END

		--> Selecting permissions
		--> Get all classes (using table variable for resole collations problemas)
		/*
			This part get the permission hierarchy of SQL Server then expands it.
			The following query get each class/permission part and generate a line for each covering permission on itself or your parent class.
			The parent of parent, and so, also is generated. For example, consider OBJECT class and EXECUTE permission:
				GRANT Execute To UserA ON mySchema.myProc;
	
			User A have explicit GRANT on mySchema.myProc (Suppose that are in database MyDB,at instance myServer\myInstance). But, SQL Server permission hierarchy may cancel this GRANT if:

				UserA have a DENY CONTROL on OBJECT mySchema.myProc
				or
				UserA have a DENY EXECUTE ON SCHEMA schema
				or
				UserA have a DENY EXECUTE ON DATABASE MyDB
				or
				UserA have a DENY CONTROL on SCHEMA mySchema
				or
				UserA have a DENY CONTROL on DATABASE MyDB
				or
				UserA have a DENY CONTROL SERVER on SERVER myServer\myInstance

			This is just the permission hierarchy of SQL Server and is valid for GRANTs also (GRANTs are implicit acquired using same concepts above).
	
			The query below just expand the hierarchy table (fn_builtin_permissions) providing data like this:

					Permission/Class		Where to Check
					EXECUTE on OBJECT	--> EXECUTE ON OBJECT
					EXECUTE on OBJECT	--> CONTROL ON OBJECT
					EXECUTE on OBJECT	--> EXECUTE ON SCHEMA
					EXECUTE on OBJECT	--> EXECUTE ON DATABASE
					EXECUTE on OBJECT	--> CONTROL ON SCHEMA
					EXECUTE on OBJECT	--> CONTROL ON DATABASE
					EXECUTE on OBJECT	--> CONTROL SERVER ON SERVER
		*/
		IF @ProgressLevel >= 5 RAISERROR('Expanding permissions to your coverings...',0,1) WITH NOWAIT;
		WITH Allis_disabledes AS
		(
			SELECT
				CONVERT(varchar(100),BP.class_desc) COLLATE Latin1_General_CI_AI	AS secClass
				,BP.permission_name	COLLATE Latin1_General_CI_AI					AS permName
				,BP.covering_permission_name COLLATE Latin1_General_CI_AI			AS coverPerm
				,BP.parent_class_desc COLLATE Latin1_General_CI_AI					AS parentSec
				,BP.parent_covering_permission_name COLLATE Latin1_General_CI_AI	AS parentCoverPerm
			FROM
				sys.fn_builtin_permissions(DEFAULT) BP
		), Expanded AS
		(
			SELECT
				AC.*
				,CONVERT(int,1)				as Level
				,AC.secClass				as RootClass
				,AC.permName				as RootPermission
				,CONVERT(decimal(2,1),1.0)	as HierarchyLevel
				,CONVERT(varchar(150),'ROOT: '+secClass+QUOTENAME(permName)) as HierarchyReason
			FROM
				Allis_disabledes AC

			UNION ALL

			SELECT
				N.*
				,CONVERT(int,E.Level + 1)
				,E.RootClass 
				,E.RootPermission

				--> If permission is joined by parent, then increment the level. If is the same, then just maintain level.
				,CONVERT(decimal(2,1),CASE
					WHEN N.secClass = E.secClass THEN E.HierarchyLevel	+ 0.1
					WHEN N.secClass = E.parentSec THEN CONVERT(int,E.HierarchyLevel) + 1.0
				END)
				,CONVERT(varchar(150),CASE
					WHEN N.secClass = E.secClass	THEN 'COVERING:'+E.secClass+'.'+E.permName
					WHEN N.secClass = E.parentSec	THEN 'PARENTOF:'+E.secClass+'.'+E.permName
				END) HierarchyReason
			FROM
				Expanded E
				INNER JOIN
				Allis_disabledes N
					ON
						--> Join current class/permission to your COVER on SAME CLASS.
						( N.secClass = E.secClass AND N.permName = E.coverPerm )
						OR
						--> Join current class/permission to your COVER on PARENT CLASS.
						( N.secClass = E.parentSec AND N.permName = E.parentCoverPerm )
		)
		SELECT
			*
		INTO
			#ExpandedChecks
		FROM
			(
				SELECT
					RootClass		
					,RootPermission
					,secClass			as className
					,permName			as permissionName
					,HierarchyLevel
					,Level
					,HierarchyReason
					--> This eliminates duplicates generated by CTE nature... Permission hierarchy of different levels can produce duplicate records...
						-- This assign a instance number, where the lowest hierarchy level have a priority.
					,ROW_NUMBER() OVER(PARTITION BY E.RootClass,E.RootPermission,E.secClass,E.permName ORDER BY E.HierarchyLevel) as InstanceNumber
				FROM
					Expanded E
			) EC
		WHERE
			EC.InstanceNumber = 1

		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'EXPANDED_PERMISSION_CHECKS',(SELECT * FROM #ExpandedChecks ORDER BY RootClass,RootPermission,Level,HierarchyLevel 
														 FOR XML PATH('Permission'),ROOT('ExpandedCheck'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END

		END

		IF @ProgressLevel >= 5 RAISERROR('Filtering permissions...',0,1) WITH NOWAIT;

		SELECT
			*
		INTO
			#FilteredPermissions
		FROM
		(
			SELECT --> Distinct eliminates duplicates permissions generated by different classes
				P.FilterType
				,P.Filter				as FilterExpressionSource
				,P.RootPermission
				,EC.permissionName
				,EC.HierarchyLevel
				,CONVERT(varchar(100),CASE 
					WHEN EC.HierarchyLevel = 1.0 THEN 'FILTERED'
					WHEN EC.HierarchyLevel > 1.0 THEN 'COVERING_ONLY'
					ELSE 'INVALID_HIERARCHY_LEVEL'
				END) COLLATE Latin1_General_CI_AI Usage

				--> This allow assign a priority to each permissions. Same PERMISSION NAME can be returned duplicate because it exists on multiple levels.
					-- When it's returned because a RootPermissions request (filtered) the lowest Hierarchy for permission will be 1.0 (a Root).
					-- When it's returned just because a covering expand, then lowest Hierachy is greather than 1.
					-- This Row_Number puts 1 on lowest hierarchy for each permission returned. Checking this value, the code will know usage.
					--	(filtered or covering only)
				,ROW_NUMBER() OVER(PARTITION BY P.FilterType,EC.permissionName ORDER BY EC.HierarchyLevel) UsagePriority
			FROM
				(
					SELECT
						EC.RootPermission
						,FT.isNot
						,FT.FilterType
						,FT.Filter
						--> This will assign a high priority to a NOT FILTER... The outer query will use priorities = 1
							-- Multiple expression can filter same value. This guarantess that values filtered by a NOT, get a high priority.
						,ROW_NUMBER() OVER(PARTITION BY FT.FilterType,EC.RootPermission ORDER BY FT.isNot DESC) FilterPriority
					FROM
					(
						--> Lets select permissions that we need.
							-- Just DISTINCT permission, without repeats generated by different classes...
						SELECT DISTINCT
							EC.RootPermission
						FROM
							#ExpandedChecks EC
					) EC
					INNER JOIN
					#FilterTable FT
						ON FT.FilterType IN ('SERVER_PERMISSION','DATABASE_PERMISSION')
						AND EC.RootPermission LIKE FT.Filter
				) P
				INNER JOIN --> More one join is need for get covering permissions...
				#ExpandedChecks EC
					ON EC.RootPermission = P.RootPermission
			WHERE
				P.FilterPriority = 1
				AND
				P.isNot = 0
		) P
		WHERE
			UsagePriority = 1


		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'FILTERED_PERMISSIONS',(SELECT * FROM #FilteredPermissions ORDER BY FilterType,RootPermission,HierarchyLevel
											FOR XML PATH('Permission'),ROOT('FilteredPermissions'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END

		-- This is all databases need we need collect some data...
		IF @ProgressLevel >= 5 RAISERROR('Filtering databases...',0,1) WITH NOWAIT;
		INSERT INTO @DatabasesToRun(name) 
		SELECT DISTINCT
			name
		FROM
		(
			SELECT 
				D.name 
				,ROW_NUMBER() OVER(PARTITION BY D.name ORDER BY FT.isNot DESC) Seq
				,FT.isNot
			FROM 
				#FilterTable FT 
				INNER JOIN
				sys.databases D
					ON D.name like FT.Filter COLLATE Latin1_General_CI_AI
			WHERE 
				FT.FilterType = 'DATABASE'
				AND
				D.state_desc = 'ONLINE'
		) D
		WHERE
			D.Seq = 1
			AND
			D.isNot = 0

		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'DATABASES_TO_RUN',(SELECT * FROM @DatabasesToRun FOR XML PATH('Database'),ROOT('FilteredDatabases'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END

		--> Creating the table that will receive filtered principals
		IF @ProgressLevel >= 5 RAISERROR('Creating the table that will receive results',0,1) WITH NOWAIT;

		SELECT TOP 0  
			  IDENTITY(bigint,1,1)						AS ID
			 ,DB_NAME()									AS scope
			,SP.name COLLATE Latin1_General_CI_AI		AS Principal
			,SP.type_desc COLLATE Latin1_General_CI_AI	AS PrincipalType
			,SP.name COLLATE Latin1_General_CI_AI		AS PrincipalSource
			,SP.principal_id							AS PrincipalSourceId
			,SP.type_desc COLLATE Latin1_General_CI_AI	AS PrincipalSourceType
			,SP.sid
			,CONVERT(sysname,NULL) COLLATE Latin1_General_CI_AI AS PrincipalMapped
			,CONVERT(bit,NULL)							AS is_default_role
			,SP.is_disabled								AS is_disabled
			,CONVERT(varchar(8000),NULL) COLLATE Latin1_General_CI_AI as SourcePath
		INTO
			#FilteredPrincipals
		FROM 
			sys.server_principals SP

		--> Creating the table that will receive filtered objects
		IF @ProgressLevel >= 5 RAISERROR('Creating the table that will receive filtered objects',0,1) WITH NOWAIT;

		SELECT TOP 0  
			  IDENTITY(bigint,1,1)						AS ID
			,DB_NAME() COLLATE Latin1_General_CI_AI		AS scope
			,o.object_id								AS SecurableID
			,O.name COLLATE Latin1_General_CI_AI		AS SecurableName
			,O.type_desc COLLATE Latin1_General_CI_AI	AS SecurableClass
			,CONVERT(xml,NULL)							AS SecurableAdditional	
		INTO
			#FilteredObjects
		FROM 
			sys.objects O

	
	--> First, collect server principals based on filter...
		IF @ProgressLevel >= 5 RAISERROR('Collecting server principals...',0,1) WITH NOWAIT;

		INSERT INTO
			#FilteredPrincipals
		SELECT DISTINCT
			 NULL
			,SP.name COLLATE Latin1_General_CI_AI		AS Principal
			,SP.type_desc COLLATE Latin1_General_CI_AI	AS PrincipalType
			,SP.name COLLATE Latin1_General_CI_AI		AS PrincipalSource
			,SP.principal_id							AS PrincipalSourceId
			,SP.type_desc COLLATE Latin1_General_CI_AI	AS PrincipalSourceType
			,SP.sid
			,NULL										AS PrincipalMapped
			,CASE
				WHEN SP.name COLLATE Latin1_General_CI_AI IN (SELECT SUSER_NAME(FSP.grantee_principal_id) COLLATE Latin1_General_CI_AI FROM #FixedServerRolePermissions FSP) THEN 1
				WHEN SP.name IN ('public') THEN 1
				ELSE 0
			END
			,SP.is_disabled
			,NULL
		FROM
			(
				SELECT
					SP.*
					,ROW_NUMBER() OVER(PARTITION BY SP.name ORDER BY FT.isNot DESC) Seq
					,FT.isNot
				FROM
					sys.server_principals SP
					INNER JOIN
					#FilterTable FT
						ON 
							(FT.FilterType ='PRINCIPAL' AND SP.name COLLATE Latin1_General_CI_AI like FT.Filter)
			) SP
		WHERE
			SP.Seq = 1
			AND
			SP.isNot = 0

		UNION ALL
	
		--> This force a Windows Login that not directly created be returned.
		SELECT DISTINCT
			 NULL
			,FU.name		AS Principal
			,FU.type_desc	AS PrincipalType
			,FU.*
		FROM
			(
				SELECT
					SUSER_SNAME(SUSER_SID(FT.Filter)) as name
					,0 as PrincipalSourceId
					,'WINDOWS_LOGIN' COLLATE Latin1_General_CI_AI as type_desc
					,SUSER_SID(FT.Filter) AS sid
					,NULL										AS PrincipalMapped
					,0 as is_default_role
					,0 as is_disabled
					,NULL as SourcePath
				FROM
					#FilterTable FT
				WHERE
					FT.FilterType = 'PRINCIPAL'
					AND
					FT.isNot = 0
			) FU
		WHERE
			FU.name IS NOT NULL
			AND
			--> Return just if dont exists on server principals
			NOT EXISTS (
				SELECT 
					* 
				FROM 
					sys.server_principals SP
				WHERE
					SP.name = FU.name
			)

			
				
	--> Lets, collect all principals for each database filtered
		IF @ProgressLevel >= 5 RAISERROR('Collecting all principals on filtered databases...',0,1) WITH NOWAIT;

		SET @dynQuery =N'
			USE [?];

			IF @ProgressLevel >= 6 RAISERROR("Collecting principals on database ?",0,1) WITH NOWAIT;

			INSERT INTO
				#FilteredPrincipals
			SELECT DISTINCT
				 DB_NAME() COLLATE Latin1_General_CI_AI
				,P.name COLLATE Latin1_General_CI_AI AS			Principal
				,P.type_desc COLLATE Latin1_General_CI_AI AS	PrincipalType
				,P.name COLLATE Latin1_General_CI_AI AS			PrincipalSource
				,P.principal_id									PrincipalSourceId
				,P.type_desc COLLATE Latin1_General_CI_AI AS	PrincipalSourceType
				,P.sid
				,SP.name COLLATE Latin1_General_CI_AI	PrincipalMapped
				,P.is_fixed_role
				,CONVERT(bit,0)
				,NULL as SourcePath
			FROM
				(
					SELECT
						P.*
						,ROW_NUMBER() OVER(PARTITION BY P.name ORDER BY FT.isNot DESC) Seq
						,FT.isNot
					FROM
						sys.database_principals P
						INNER JOIN
						#FilterTable FT
							ON 
								(FT.FilterType ="PRINCIPAL" AND P.name COLLATE Latin1_General_CI_AI like FT.Filter)
								OR
								--> Filter DB principals based on mapped name also. Dont use the server_principals because some users at login level cannot exists more...
								(FT.FilterType ="PRINCIPAL" AND SUSER_SNAME(P.sid) COLLATE Latin1_General_CI_AI like FT.Filter)
				) P
				LEFT JOIN
				sys.server_principals SP
					ON SP.sid = P.sid
			WHERE
				P.Seq = 1
				AND
				P.isNot = 0
		'

		SET @dynQuery = REPLACE(@dynQuery,'"','''');

		SET @CurrentRunningDB = 1;
		WHILE EXISTS(SELECT * FROM @DatabasesToRun DTR WHERE DTR.ID >= @CurrentRunningDB)
		BEGIN
			SELECT @DbName = DTR.name FROM @DatabasesToRun DTR WHERE DTR.ID = @CurrentRunningDB;

			SET @dynQueryFinal = REPLACE(@dynQuery,'?',@DbName);
		
			IF @ProgressLevel >= 5 RAISERROR('STARTING Collecting principals on database %s',0,1,@dbName) WITH NOWAIT;
		
			EXEC sp_executesql @dynqueryFinal,N'@ProgressLevel int',@ProgressLevel;

			SET @CurrentRunningDB = @CurrentRunningDB + 1;
		END



				
	--> Lets, collect all object for each database filtered
		IF @ProgressLevel >= 5 RAISERROR('Collecting all objects on filtered databases...',0,1) WITH NOWAIT;

		SET @dynQuery =N'
			USE [?];

			IF @ProgressLevel >= 6 RAISERROR("Collecting objects on database ?",0,1) WITH NOWAIT;

			INSERT INTO
				#FilteredObjects
			SELECT
				 DB_NAME() COLLATE Latin1_General_CI_AI				AS scope
				,S.SecurableID
				,S.SecurableName COLLATE Latin1_General_CI_AI		AS SecurableName
				,S.SecurableClass COLLATE Latin1_General_CI_AI		AS SecurableClass
				,S.SecurableAdditional
			FROM
				(
					SELECT
						 O.*
						,ROW_NUMBER() OVER(PARTITION BY SecurableID ORDER BY FT.isNot DESC) Seq
						,FT.isNot
					FROM 
						(
							SELECT
								 SecurableID		= O.object_id
								,SecurableName		= O.name
								,SecurableClass		= ''OBJECT''
								,SecurableAdditional	= (
															--> This select will generate the additional info for each SecurableName like schema_id, and database_id....
															SELECT
																O.schema_id					as "SCHEMA/@ID"
																,DB_ID()					as "DATABASE/@ID"
																,O.object_id				as "OBJECT/@ID"
															FOR XML PATH(""),ROOT("info")
														)
							FROM
								sys.objects O
						) O
						INNER JOIN
						#FilterTable FT
							ON 
								FT.FilterType ="SECURABLE" AND O.SecurableName COLLATE Latin1_General_CI_AI like FT.Filter
				) S
			WHERE
				Seq = 1
				AND
				isNot = 0
		'

		SET @dynQuery = REPLACE(@dynQuery,'"','''');
		SET @CurrentRunningDB = 1;
		WHILE EXISTS(SELECT * FROM @DatabasesToRun DTR WHERE DTR.ID >= @CurrentRunningDB)
		BEGIN
			SELECT @DbName = DTR.name FROM @DatabasesToRun DTR WHERE DTR.ID = @CurrentRunningDB;
			SET @dynQueryFinal = REPLACE(@dynQuery,'?',@DbName);
			IF @ProgressLevel >= 5 RAISERROR('STARTING Collecting objects on database %s',0,1,@dbName) WITH NOWAIT;
			EXEC sp_executesql @dynqueryFinal,N'@ProgressLevel int',@ProgressLevel;
			SET @CurrentRunningDB = @CurrentRunningDB + 1;
		END




	IF @ShowDefaultRoles = 0
	BEGIN
		IF @ProgressLevel >= 5 RAISERROR('Deleting defaults roles...',0,1) WITH NOWAIT;
		DELETE FROM #FilteredPrincipals WHERE is_default_role = 1;
	END

	--> Now, lets check a Windows Membership.
	IF @DisableTokenCheck = 0 AND @MembershipLevel >= 1
	BEGIN
		IF @ProgressLevel >= 5 RAISERROR('Collecting logins for expand via token.',0,1) WITH NOWAIT;

		INSERT INTO 
			@LoginsForExpand
		SELECT 
			L.Principal
		FROM
			(
				SELECT DISTINCT
					 CASE
						WHEN F.scope IS NOT NULL THEN SUSER_SNAME(F.sid)
						ELSE F.PrincipalSource
					END COLLATE Latin1_General_CI_AI as Principal
				FROM 
					#FilteredPrincipals F
				WHERE 
					F.PrincipalSourceType IN ('WINDOWS_USER','WINDOWS_LOGIN')
			) L
		WHERE
			L.Principal IS NOT NULL
		;

		/*
			Here happens a curious thing (I experimented this issue on SQL 2008 R2) (Rodrigo, where are you?)
			Initially, the procedure tried connect on "tempdb", impersonate the user, then extract token information.
			But, if impersonated login dont have permission to connect on master, but in tempdb it do, the EXECUTE AS LOGIN will execute with sucess, but REVERT fails...
			Then, outer query will execute in context of @LoginName... Shit... If it was a restricted user, then all proc can fail...
			Because this I execute the query on "master". If use dont have permission to connect no it, the EXECUTE AS LOGIN will fail before context be changed.
			This prevent some Shits... Shit... Shit.... 
			I guess that is a bug, already in BOL of REVERT permission sectino dont mentions any permission on master... Shit again...
		*/
		SET @dynQuery = N'
			USE master; --> ShitCause
	
			DECLARE @contextChanged bit
				SET @contextChanged = 0; --> For case same proc executor and login verify
	
			IF @ProgressLevel >= 1	RAISERROR("Impersonating the user %s for collect token informations...",0,1,@LoginName) WITH NOWAIT;
	
			IF (SUSER_NAME() COLLATE Latin1_General_CI_AI) != (@LoginName COLLATE Latin1_General_CI_AI)
			BEGIN
				EXECUTE AS LOGIN = @LoginName;
				SET @contextChanged = 1;
			END
	
			BEGIN TRY
				IF @ProgressLevel >= 6	RAISERROR("Accesing token for %s",0,1,@LoginName) WITH NOWAIT;
				SELECT DISTINCT SUSER_NAME() COLLATE Latin1_General_CI_AI,name COLLATE Latin1_General_CI_AI FROM sys.login_token WHERE type = ''WINDOWS GROUP''
				IF @ProgressLevel >= 6	RAISERROR("	OK",0,1) WITH NOWAIT;
			END TRY
			BEGIN CATCH
					print "	ERROR WHEN COLLECT TOKEN FOR "+@LoginName
					print "		"+ERROR_MESSAGE()

					BEGIN TRY
						INSERT INTO #Warnings VALUES("Error when getting login token for "+@LoginName+"... Results may not include covering permissions");
						INSERT INTO #Warnings VALUES(REPLICATE(CHAR(9),5)+ERROR_MESSAGE());
					END TRY
					BEGIN CATCH
						print "	ERROR WHEN INSERTING WARNINGS TOKEN FOR "+@LoginName
						print "		"+ERROR_MESSAGE()
					END CATCH

					IF @contextChanged = 1
						REVERT;
			
					RETURN;
			END CATCH

			IF @contextChanged = 1
			BEGIN
				REVERT;
			END

			IF @ProgressLevel >= 1
			BEGIN
				IF @@Error = 0
					print "	SUCESS!"
			END
		'

		SET @dynQuery = REPLACE(@dynQuery,'"','''');

		--Setting some control variables
		SET @OriginalLogin = SUSER_NAME();
		SET @CurrentLogin = 1;
	
		WHILE EXISTS(SELECT * FROM @LoginsForExpand LE WHERE LE.ID >= @CurrentLogin )
		BEGIN
			--> Get login name...
			SELECT @LoginName = LE.winLogin FROM @LoginsForExpand LE WHERE LE.id = @CurrentLogin;

			-- Trying get login token..
			BEGIN TRY
				IF @ProgressLevel >= 5	RAISERROR('Starting dynamic query to collect login token %s',0,1,@LoginName) WITH NOWAIT;
				INSERT INTO #LoginTokenResults
				EXEC sp_executesql @dynQuery,N'@LoginName sysname, @ProgressLevel smallint',@LoginName,@ProgressLevel;
			END TRY
			BEGIN CATCH
				IF @ProgressLevel >= 6	RAISERROR('Error when getting login token for %s',0,1,@LoginName) WITH NOWAIT;
				INSERT INTO #Warnings VALUES('Error when getting login token for '+@LoginName+'... Results may not include ALL covering permissions');
				INSERT INTO #Warnings VALUES(REPLICATE(CHAR(9),5)+ERROR_MESSAGE());
			END CATCH

			--> If after execute the current user is not original... Try revert...
			IF SUSER_NAME() != @OriginalLogin
			BEGIN
				RAISERROR('Token Query exited with impersonation user %s... Attempting revert... If no error message after this, revert ok',0,1,@LoginName) WITH NOWAIT;
				EXEC sp_executesql N'USE master; REVERT'; --> Curious thing: EXEC dont Works... sp_executesql works!
			
				--> Same if after above attempt the context still different than original, then fails de proc.
				IF SUSER_NAME() != @OriginalLogin
				BEGIN
					RAISERROR('IMPOSSIBLE REVERT CONTEXT. Your session is running under the user %s. Call REVERT. Re-run procedure with @DisableTokenCheck = 1.',16,1,@LoginName) WITH NOWAIT;
					RETURN;
				END
			END

			SET @CurrentLogin = @CurrentLogin + 1;
		END

		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'LOGIN_TOKEN_RESULTS',(SELECT * FROM #LoginTokenResults ORDER BY winLogin,groupName
											FOR XML PATH('LoginToken'),ROOT('LoginTokenResults'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END;

	END




	--> Lets insert valid groups (these that are on principals) as a filtered principal

		IF @ProgressLevel >= 5	RAISERROR('Inserting membership from Windows on #FilteredPrincipals',0,1,@LoginName) WITH NOWAIT;

		-- First, back server level groups
		INSERT INTO
			#FilteredPrincipals
		SELECT
			 FP.scope
			,FP.Principal
			,FP.PrincipalType
			,SP.name COLLATE Latin1_General_CI_AI		PrincipalSource
			,SP.principal_id							PrincpalSourceId
			,SP.type_desc COLLATE Latin1_General_CI_AI	PrincipalSourceType
			,SP.sid
			,NULL										AS PrincipalMapped
			,0
			,SP.is_disabled
			,SP.name +' --> '+FP.Principal as SourcePath
		FROM
			#LoginTokenResults LT
			INNER JOIN
			#FilteredPrincipals FP
				ON FP.Principal = LT.winLogin
			INNER JOIN
			sys.server_principals SP
				ON SP.name COLLATE Latin1_General_CI_AI = LT.groupName
		WHERE
			FP.scope IS NULL


		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'FILTERED_PRINCIPALS_SERVER',(SELECT * FROM #FilteredPrincipals ORDER BY Principal,PrincipalSource
											FOR XML PATH('Principal'),ROOT('FilteredPrincipals'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END;
		
		--> Now, lets get database principals...

		SET @dynQuery =N'
			USE [?];

			IF @ProgressLevel >= 6	RAISERROR("Inserting membership from Windows on #FilteredPrincipals for DB PRINCIPALS at ?",0,1) WITH NOWAIT;

			SELECT
				 ISNULL(FP.scope,DB_NAME())
				,ISNULL(FP.Principal,LTR.winLogin)
				,ISNULL(FP.PrincipalType,''WINDOWS_LOGIN'')
				,DP.name COLLATE Latin1_General_CI_AI AS		PrincipalSource
				,DP.principal_id								PrincipalSourceId
				,DP.type_desc COLLATE Latin1_General_CI_AI AS	PrincipalSourceType
				,DP.sid
				,SP.name COLLATE Latin1_General_CI_AI AS PrincipalMapped
				,DP.is_fixed_role
				,CONVERT(bit,0)
				,DP.name +" --> "+ISNULL(FP.Principal,LTR.winLogin) COLLATE Latin1_General_CI_AS as SourcePath
			FROM
				#LoginTokenResults LTR
				INNER JOIN
				sys.database_principals DP
					ON DP.name COLLATE Latin1_General_CI_AI = LTR.groupName
				LEFT JOIN
				#FilteredPrincipals FP
					ON LTR.winLogin = SUSER_SNAME(FP.sid) OR LTR.winLogin = FP.PrincipalSource
					AND FP.scope = DB_NAME()
				LEFT JOIN
				sys.server_principals SP
					ON SP.sid = DP.sid
			
		'
		
		SET @dynQuery = REPLACE(@dynQuery,'"','''');

		SET @CurrentRunningDB = 1;
		WHILE EXISTS(SELECT * FROM @DatabasesToRun DTR WHERE DTR.ID >= @CurrentRunningDB)
		BEGIN
			SELECT @DbName = DTR.name FROM @DatabasesToRun DTR WHERE DTR.ID = @CurrentRunningDB;

			SET @dynQueryFinal = REPLACE(@dynQuery,'?',@DbName);
		
			IF @ProgressLevel >= 5 RAISERROR('STARTING Expanding Windows membership on database %s',0,1,@dbName);
		
			INSERT INTO #FilteredPrincipals
			EXEC sp_executesql @dynqueryFinal,N'@ProgressLevel int',@ProgressLevel;

			SET @CurrentRunningDB = @CurrentRunningDB + 1;
		END

		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'FILTERED_PRINCIPALS_DATABASE',(SELECT * FROM #FilteredPrincipals WHERE scope IS NOT NULL ORDER BY Principal,PrincipalSource
											FOR XML PATH('Principal'),ROOT('DatabaseFilteredPrincipals'),TYPE)

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END;

	-- Now, lets expand membership on roles
		IF @MembershipLevel >= 1
		BEGIN
			IF @ProgressLevel >= 5	RAISERROR('Expanding roles at SERVER SCOPE',0,1) WITH NOWAIT;

			-- First, lets expand membership on server principals...
			;WITH RoleExpansion AS
			(
				SELECT
					 FP.scope
					,FP.Principal
					,FP.PrincipalType
					,RM.role_principal_id as NewPid
					,CONVERT(varchar(8000),SUSER_NAME(RM.role_principal_id) +' --> '+ SUSER_NAME(FP.PrincipalSourceId)) COLLATE Latin1_General_CI_AI SourcePath
				FROM
					#FilteredPrincipals FP
					INNER JOIN
					sys.server_role_members RM
						ON RM.member_principal_id = FP.PrincipalSourceId
				WHERE
					FP.scope IS NULL

				UNION ALL

				SELECT
					 FP.scope
					,FP.Principal
					,FP.PrincipalType
					,RM.role_principal_id as NewPid
					,CONVERT(varchar(8000),SUSER_NAME(FP.NewPid)) +' --> '+  FP.SourcePath 
				FROM
					RoleExpansion FP
					INNER JOIN
					sys.server_role_members RM
						ON RM.member_principal_id = FP.NewPid  
			)
			INSERT INTO	
				#FilteredPrincipals
			SELECT
				RE.scope
				,RE.Principal
				,RE.PrincipalType
				,SP.name COLLATE Latin1_General_CI_AI		PrincipalSource
				,SP.principal_id							PrincipalSourceId
				,SP.type_desc COLLATE Latin1_General_CI_AI	PrincipalSourceType
				,SP.sid
				,NULL										PrincipalMapped
				,0
				,SP.is_disabled
				,RE.SourcePath
			FROM
				RoleExpansion RE
				INNER JOIN
				sys.server_principals SP
					ON SP.principal_id = RE.NewPid
			OPTION(MAXRECURSION 0)
		END
	
		-- Now, more one time, lets get on expand database principals role membership =D ...
		IF @MembershipLevel >= 1
		BEGIN
			SET @dynQuery =N'
				USE [?];

				IF @MembershipLevel >= 1
				BEGIN

				IF @ProgressLevel >= 6	RAISERROR("Expanding DATABASE ROLES at ?",0,1) WITH NOWAIT;

					;WITH RoleExpansion AS
					(
						SELECT
							 FP.scope
							,FP.Principal
							,FP.PrincipalType
							,RM.role_principal_id as NewPid
							,CONVERT(varchar(8000),USER_NAME(RM.role_principal_id) +" --> "+ USER_NAME(FP.PrincipalSourceId)) COLLATE Latin1_General_CI_AI SourcePath
						FROM
							#FilteredPrincipals FP
							INNER JOIN
							sys.database_role_members RM
								ON RM.member_principal_id = FP.PrincipalSourceId
						WHERE
							FP.scope = DB_NAME()

						UNION ALL

						SELECT
							 FP.scope
							,FP.Principal
							,FP.PrincipalType
							,RM.role_principal_id as NewPid
							,CONVERT(varchar(8000),USER_NAME(RM.role_principal_id)) +" --> "+  FP.SourcePath 
						FROM
							RoleExpansion FP
							INNER JOIN
							sys.database_role_members RM
								ON RM.member_principal_id = FP.NewPid  
					)
					SELECT
						RE.scope
						,RE.Principal
						,RE.PrincipalType
						,DP.name COLLATE Latin1_General_CI_AI AS		PrincipalSource
						,DP.principal_id								PrincipalSourceId
						,DP.type_desc COLLATE Latin1_General_CI_AI AS	PrincipalSourceType
						,DP.sid
						,SUSER_SNAME(DP.sid) COLLATE Latin1_General_CI_AI AS PrincipalMapped
						,DP.is_fixed_role
						,CONVERT(bit,0)
						,RE.SourcePath
					FROM
						RoleExpansion RE
						INNER JOIN
						sys.database_principals DP
							ON DP.principal_id = RE.NewPid
					OPTION(MAXRECURSION 0)

				END
			'
	
			SET @dynQuery = REPLACE(@dynQuery,'"','''');

			SET @CurrentRunningDB = 1;
			WHILE EXISTS(SELECT * FROM @DatabasesToRun DTR WHERE DTR.ID >= @CurrentRunningDB)
			BEGIN
				SELECT @DbName = DTR.name FROM @DatabasesToRun DTR WHERE DTR.ID = @CurrentRunningDB;

				SET @dynQueryFinal = REPLACE(@dynQuery,'?',@DbName);
		
				IF @ProgressLevel >= 5 RAISERROR('STARTING Expanding ROLES membership on database %s',0,1,@dbName) WITH NOWAIT;
		
				INSERT INTO #FilteredPrincipals
				EXEC sp_executesql @dynqueryFinal,N'@ProgressLevel int, @MembershipLevel int',@ProgressLevel, @MembershipLevel;

				IF @ProgressLevel >= 5 RAISERROR('	OK',0,1) WITH NOWAIT;

				SET @CurrentRunningDB = @CurrentRunningDB + 1;
			END
		END

	--> At this point, all principals filtered and your expansions was collected. Now, lets start collect permissions and securables...
		IF @ProgressLevel >= 5 RAISERROR('Collectiing server level permissions',0,1) WITH NOWAIT;

		-- Server level permissions...
		SELECT
			 FP.ID
			,P.permission_name COLLATE Latin1_General_CI_AI as [Permission]
			,P.PermissionUsage
			,P.state_desc		COLLATE Latin1_General_CI_AI AS PermissionState
			,P.class_desc		COLLATE Latin1_General_CI_AI AS SecurablePermissionClass
			,P.major_id			AS SecurableID
			,P.minor_id
			,CONVERT(varchar(500),CASE 
								WHEN P.class_desc COLLATE Latin1_General_CI_AI = 'SERVER' COLLATE Latin1_General_CI_AI  THEN @@SERVERNAME
								ELSE P.class_desc+': '+CONVERT(varchar(20),P.major_id)+'.'+CONVERT(varchar(20),P.minor_id	)
							END
				) COLLATE Latin1_General_CI_AI AS SecurableName
			,CONVERT(varchar(100),NULL) COLLATE Latin1_General_CI_AI as ColumnName
			,CONVERT(varchar(100),NULL) COLLATE Latin1_General_CI_AI as SecurableType
			,CONVERT(varchar(100),
				CASE
					WHEN P.class_desc IS NULL THEN 'LOGIN' --> This is a special case of this script. When, NULL the user was manually generated by @Filter...
					WHEN P.class_desc = 'SERVER_PRINCIPAL' AND FP.PrincipalSourceType NOT IN ('SERVER_ROLE') THEN 'LOGIN'
					WHEN P.class_desc = 'SERVER_PRINCIPAL' AND FP.PrincipalSourceType IN ('SERVER_ROLE') THEN 'SERVER ROLE'
					ELSE P.class_desc
				END
			)  COLLATE Latin1_General_CI_AI as SecurableClass
			,CONVERT(XML,NULL) as SecurableAdditional
		INTO
			#RawPermissions
		FROM
			#FilteredPrincipals FP
			INNER JOIN
			(
				SELECT
					P.*
					,FP.Usage as PermissionUsage
				FROM
				(
					SELECT
						*
					FROM
						sys.server_permissions SP

					UNION ALL

					SELECT
						*
					FROM
						#FixedServerRolePermissions SRP
				) P
				INNER JOIN
				#FilteredPermissions FP
					ON FP.FilterType = 'SERVER_PERMISSION'
					AND FP.permissionName COLLATE Latin1_General_CI_AI = P.permission_name
			) P
				ON P.grantee_principal_id = FP.PrincipalSourceId
			
		WHERE
			FP.scope IS NULL
			AND --> This filter ensures that, if membership level isn't set to collect permissions, just direct permission will be collected
			(
				(FP.Principal = FP.PrincipalSource)
				OR
				@MembershipLevel >= 2
			)


		-- Now, get permissions on database level
		SET @dynQuery =N'
			USE [?];

			IF @ProgressLevel >= 6 RAISERROR("Collecting permissions on database ?",0,1) WITH NOWAIT;

			SELECT
				 FP.ID
				,P.permission_name COLLATE Latin1_General_CI_AI as [Permission]
				,P.PermissionUsage
				,P.state_desc		COLLATE Latin1_General_CI_AI AS PermissionState
				,P.class_desc		COLLATE Latin1_General_CI_AI AS SecurablePermissionClass
				,CASE
					WHEN P.class_desc = "DATABASE" COLLATE Latin1_General_CI_AI THEN DB_ID()
					ELSE P.major_id
				END AS SecurableID
				,P.minor_id
				,CONVERT(varchar(500),ISNUll(SEC.securableName,P.class_desc+": "+CONVERT(varchar(20),P.major_id)+"."+CONVERT(varchar(20),P.minor_id)) 
					) COLLATE Latin1_General_CI_AI AS O
				,CONVERT(varchar(500),CASE 
										WHEN P.minor_id > 0 AND SEC.SecurableType LIKE "%TABLE%" COLLATE Latin1_General_CI_AI  THEN COL_NAME(P.major_id,P.minor_id) COLLATE Latin1_General_CI_AI
										WHEN P.minor_id = 0 AND SEC.SecurableType LIKE "%TABLE%" COLLATE Latin1_General_CI_AI  THEN "*" COLLATE Latin1_General_CI_AI
								END
				 ) COLLATE Latin1_General_CI_AI AS ColumnName
				 ,SEC.SecurableType
				 ,SEC.SecurableClass
				 ,SEC.SecurableAdditional
			FROM
				#FilteredPrincipals FP
				INNER JOIN
				(
					SELECT
						P.*
						,FP.Usage as PermissionUsage
					FROM
						(
							SELECT
								*
							FROM
								sys.database_permissions SP

							UNION ALL

							SELECT
								*
							FROM
								#FixedRolePermissions FRP
						) P
					INNER JOIN
					#FilteredPermissions FP
						ON FP.FilterType = "DATABASE_PERMISSION"
						AND FP.permissionName COLLATE Latin1_General_CI_AI = P.permission_name
				) P
					ON P.grantee_principal_id = FP.PrincipalSourceId
				OUTER APPLY
					(
						SELECT
							 CONVERT(varchar(100),"DATABASE") COLLATE Latin1_General_CI_AI		as secSecurablePermissionClass	
							,DB_ID()															as securableID
							,CONVERT(nvarchar(300),DB_NAME()) COLLATE Latin1_General_CI_AI		as securableName
							,NULL																as SecurableType
							,NULL																as SecurableClass
							,CONVERT(XML,NULL)													as SecurableAdditional
						WHERE
							P.class_desc = "DATABASE"

						UNION ALL

						SELECT
							 CONVERT(varchar(100),"OBJECT_OR_COLUMN") COLLATE Latin1_General_CI_AI	as secSecurablePermissionClass	
							,O.object_id 															as securableID
							,CONVERT(nvarchar(300),O.name) COLLATE Latin1_General_CI_AI				as securableName
							,CONVERT(varchar(100),O.type_desc) COLLATE Latin1_General_CI_AI			as SecurableType
							,CONVERT(varchar(100),"OBJECT") COLLATE Latin1_General_CI_AI			as SecurableClass
							,(
								--> This select will generate the additional info for each SecurableName like schema_id, and database_id....
								SELECT
									O.schema_id					as "SCHEMA/@ID"
									,DB_ID()					as "DATABASE/@ID"
									,O.object_id				as "OBJECT/@ID"
								FOR XML PATH(""),ROOT("info")

							) 																		as SecurableAdditional
						FROM
							sys.all_objects O
						WHERE
							O.object_id = P.major_id
							AND
							P.class_desc = "OBJECT_OR_COLUMN"

						UNION ALL

						SELECT
							 CONVERT(varchar(100),"SCHEMA") COLLATE Latin1_General_CI_AI	
							,S.schema_id
							,CONVERT(nvarchar(300),S.name) COLLATE Latin1_General_CI_AI	
							,NULL
							,NULL
							,(
								--> This select will generate the additional info for each SecurableName like schema_id, and database_id....
								SELECT
									S.schema_id					as "SCHEMA/@ID"
									,DB_ID()					as "DATABASE/@ID"
								FOR XML PATH(""),ROOT("info")

							)  as SecurableAdditional
						FROM
							sys.schemas S
						WHERE
							S.schema_id = P.major_id
							AND
							P.class_desc = "SCHEMA"

						UNION ALL

						SELECT
							CONVERT(varchar(100),"DATABASE_PRINCIPAL") COLLATE Latin1_General_CI_AI
							,DP.principal_id
							,CONVERT(nvarchar(300),DP.name) COLLATE Latin1_General_CI_AI	
							,CONVERT(varchar(100),DP.type_desc)	COLLATE Latin1_General_CI_AI
							,CASE
								WHEN DP.type_desc LIKE "%USER" THEN "USER"
								WHEN DP.type_desc LIKE "%GROUP" THEN "USER"
								WHEN DP.type_desc = "DATABASE_ROLE" THEN "ROLE"
								WHEN DP.type_desc = "APPLICATION_ROLE" THEN "APPLICATION ROLE"
								ELSE DP.type_desc
							END
							,NULL
						FROM
							sys.database_principals DP
						WHERE
							DP.principal_id = P.major_id
							AND
							P.class_desc = "DATABASE_PRINCIPAL"
					
					) SEC
			WHERE
				FP.scope = DB_NAME() COLLATE Latin1_General_CI_AI
				AND --> This filter ensures that, if membership level isnt set to collect permissions, just direct permission will be collected
				(
					(FP.Principal = FP.PrincipalSource)
					OR
					@MembershipLevel >= 2
				)

			;
		'
	
		SET @dynQuery = REPLACE(@dynQuery,'"','''');

		SET @CurrentRunningDB = 1;
		WHILE EXISTS(SELECT * FROM @DatabasesToRun DTR WHERE DTR.ID >= @CurrentRunningDB)
		BEGIN
			SELECT @DbName = DTR.name FROM @DatabasesToRun DTR WHERE DTR.ID = @CurrentRunningDB;

			SET @dynQueryFinal = REPLACE(@dynQuery,'?',@DbName);
		
			IF @ProgressLevel >= 5 RAISERROR('Starting collect permissions on database %s',0,1,@dbName) WITH NOWAIT;

			INSERT INTO #RawPermissions
			EXEC sp_executesql @dynqueryFinal,N'@ProgressLevel int,@MembershipLevel int',@ProgressLevel,@MembershipLevel;

			IF @ProgressLevel >= 5 RAISERROR('	OK',0,1) WITH NOWAIT;

			SET @CurrentRunningDB = @CurrentRunningDB + 1;
		END


	IF @ProgressLevel >= 5 RAISERROR('Generating raw permissions',0,1) WITH NOWAIT;

	SELECT
		IDENTITY(bigint,1,1)	AS PPID
		,FP.ID					AS FPID

		,FP.scope

		--> User data
		,FP.Principal
		,FP.PrincipalType

		--> Source principal
		,FP.PrincipalSource					--AS USrc
		,FP.PrincipalSourceType				--AS USrcType
		,FP.PrincipalMapped
		,~FP.is_disabled					AS PrincipalActive
		,FP.SourcePath	

		--> Permissions
		,RP.[Permission]
		,RP.PermissionState
		,RP.PermissionUsage

		--> SecurableName (Target, object, etc.)
		,RP.SecurableName
		,RP.SecurableName+ISNULL('.'+RP.ColumnName,'') as SecurableFull
		,RP.SecurablePermissionClass
		,RP.SecurableType
		,CONVERT(varchar(100),ISNULL(RP.SecurableClass,RP.SecurablePermissionClass)) COLLATE Latin1_General_CI_AI	  SecurableClass
		,RP.SecurableID
		,RP.minor_id
		,RP.SecurableAdditional
	INTO
		#PrincipalsPermissions
	FROM
		#FilteredPrincipals FP
		LEFT JOIN
		#RawPermissions RP
			ON RP.ID = FP.ID


		



	IF @DetailsLevel = 1 
	BEGIN
		IF OBJECT_ID('tempdb..#Final_RawResults') IS NOT NULL
			DROP TABLE #Final_RawResults;

		SET @DefaultColumnsList = '*';
		SET @DefaultOrderBy = 'scope,Principal,PermissionState,PrincipalSource';

		SELECT
			--> Scope info
			E.scope

			--> Principal info
			,E.Principal
			,E.PrincipalType
			,E.PrincipalSource
			,E.PrincipalSourceType
			,E.PrincipalMapped
			,E.PrincipalActive
		
			--> SecurableName info
			,E.SecurableFull as Securable
			,ISNULL(E.SecurableType,E.SecurableClass) SecurableType
		
			--> Permission info
			,E.[Permission]
			,E.PermissionState

			--. Additional info
			,E.SourcePath
		INTO
			#Final_RawResults
		FROM
			#PrincipalsPermissions E

		SET @FinalDataSource = '#Final_RawResults';

	END

	IF @DetailsLevel >= 2
		BEGIN

			IF @ProgressLevel >= 5 RAISERROR('Indexiing for permission hierarchy...',0,1) WITH NOWAIT;	


			IF @CoverDeniedOnly = 1
			BEGIN
				SET @dynQuery = 'CREATE INDEX ixCover_WithState ON #PrincipalsPermissions (PermissionState
																						   ,Principal
																						   ,SecurableClass
																						   ,[Permission]
																						   ,scope
																						   ,SecurableID
																						   ,minor_id
																						   ,SecurableName
																						  ) INCLUDE(SecurableFull,PrincipalSource)
								';
				-- If supports filtered indexes...
				IF @SqlVersion >= 10
					SET @dynQuery = @dynQuery + ' WHERE PermissionState = ''DENY'' ';
			END
			ELSE
				SET @dynQuery = 'CREATE INDEX ixCover_WithState ON #PrincipalsPermissions (Principal
																						   ,SecurableClass
																						   ,[Permission]
																						   ,scope
																						   ,SecurableID
																						   ,minor_id
																						   ,SecurableName
																						  ) INCLUDE(SecurableFull,PrincipalSource,PermissionState)'
			
			EXEC(@dynQuery);
			CREATE CLUSTERED INDEX ixCluster ON #ExpandedChecks (RootClass,RootPermission);
			CREATE CLUSTERED INDEX ixCluster ON #PrincipalsPermissions(scope,PrincipalSource,Principal,PPID,PermissionUsage);


			IF @ProgressLevel >= 5 RAISERROR('Resolving hierarchy permissions on collected permissions...',0,1) WITH NOWAIT;	
	

			SELECT
				 PP.PPID
				,EC.*
			INTO
				#CoveringPermissions
			FROM
				(
					SELECT
						*
						,PP.SecurableAdditional.value('(./info/SCHEMA/@ID)[1]','int')		SecurableSchemaID
						,PP.SecurableAdditional.value('(./info/DATABASE/@ID)[1]','int')		SecurableDatabaseID
						,PP.SecurableAdditional.value('(./info/OBJECT/@ID)[1]','int')		SecurableObjectID
					FROM
						#PrincipalsPermissions	 PP
					WHERE
						--> This filter ensures that, if membership level isn't set to expand covering permissions, expands happens to direct user permissions only
						(PP.Principal = PP.PrincipalSource)
						OR
						@MembershipLevel >= 3
				) PP
				OUTER APPLY
				(
	
					SELECT	
						EXC.RootClass						as '@RootClass'
						,EXC.RootPermission					as '@RootPermission'

						,EXC.className						as '@class'
						,EXC.permissionName					as '@permission'
						,EXC.HierarchyLevel					as '@level'
					
						,(
							SELECT
								 CPP.SecurableFull					as '@target'
								,CPP.PrincipalSource				as '@name'
								,CPP.PermissionState				as '@state'
							FROM
								#PrincipalsPermissions CPP
							WHERE
									(
										CPP.PermissionState = 'DENY' OR	@CoverDeniedOnly = 0
									)
								AND CPP.Principal = PP.Principal --> Same user...
								AND (CPP.scope = PP.scope OR CPP.scope IS NULL )  --> Same Scope
								AND CPP.SecurableClass = EXC.className --> same class as class own or parent (According to expanded)
								AND CPP.[Permission] = EXC.permissionName --> same permission as cover own or cover parent (According to expanded)
							
								--> This part is responsible to join to correct SecurableName. If parent, then get correct parent securableID.
								AND	CPP.SecurableID = CASE
														WHEN EXC.className = 'SCHEMA' AND EXC.HierarchyLevel >= 2 THEN PP.SecurableSchemaID
														WHEN EXC.className = 'DATABASE' AND EXC.HierarchyLevel >= 2 THEN PP.SecurableDatabaseID
														WHEN EXC.className = 'SERVER' AND EXC.HierarchyLevel >= 2 THEN 0
														WHEN PP.minor_id > 0  THEN PP.SecurableObjectID
														ELSE PP.SecurableID
													END	
									
								--> This avoids column permission be joined to other column permissions (because the SecurableID is same...)
									-- With this, just permission on FULL parent (all columns) are joined.
								AND CPP.minor_id = PP.minor_id
								AND	CPP.SecurableName = CASE
											WHEN EXC.className = 'SERVER' COLLATE Latin1_General_CI_AI	THEN CONVERT(varchar(500),@@SERVERNAME)
											ELSE CPP.SecurableName
										END COLLATE Latin1_General_CI_AI

							FOR XML PATH('U'),TYPE
						)
					FROM
						#ExpandedChecks EXC
					WHERE
						EXC.RootClass = PP.SecurableClass
						AND
						EXC.RootPermission = PP.[Permission]
					FOR XML PATH('SecurableName'),ROOT('coverings'),TYPE
				) EC(coveringInfo)
				OPTION( RECOMPILE, MAXDOP 1 )


	



		END



	IF @DetailsLevel = 2
	BEGIN
		IF OBJECT_ID('tempdb..#Final_EffectiveCoverings') IS NOT NULL
			DROP TABLE #Final_EffectiveCoverings;			
		

			CREATE CLUSTERED INDEX ixCluster ON #CoveringPermissions (PPID);

			-- Filetered counterpaart!
			IF EXISTS(SELECT * FROM #FilteredObjects)
			BEGIN
				SET @DefaultColumnsList = 'scope,FilteredSecurable,Principal,PrincipalType,PrincipalSource,PrincipalMapped,PrincipalActive,Securable,SecurableType,[Permission],PermissionState,CoverDenied,CoveringsDetails,SourcePath';
				SET @DefaultOrderBy = 'scope,FilteredSecurable,Principal,CoverDenied DESC,PermissionState,SecurableID,MinorID,Securable,PrincipalSource,[Permission]';

				
				-- Building table to determined filtered object permisisons!
				SELECT
					--> Scope info
					FO.scope
					,FilteredSecurable = FO.SecurableName

					--> Principal info
					,PP.Principal	
					,PP.PrincipalType	
					,PP.PrincipalSource	
					,PP.PrincipalSourceType
					,PP.PrincipalMapped	
					,PP.PrincipalActive

					--> Source SecurableName info
					,PP.SecurableName as Securable
					,PP.SecurableClass SecurableType
					,PP.SecurableID
					,MinorID = NULL
		
					--> Permission info
					,PP.[Permission]
					,PermissionState = ISNULL(CoverDenied,PP.PermissionState)
					,CoverDenied	= CONVERT(bit,LEN(ISNULL(CoverDenied,'')))
					,OriginalPermissionState	= PP.PermissionState
		
					--> Addiitiona level info
					,PP.coveringInfo	 AS CoveringsDetails
		
					--> Additional user info
					,SourcePath = PP.PrincipalSource+'('+PP.PrincipalSourceType+')'
				INTO
					#Final_EffectiveCoverings_Filtered
				FROM 
					#FilteredObjects FO
					OUTER APPLY (
						SELECT
							PP.*
							,cp.coveringInfo
							,CoverDenied = NULLIF(CP.coveringInfo.value('string((./coverings/SecurableName/U[@state = "DENY"]/@state)[1])','varchar(30)'),'')
						FROM
							#PrincipalsPermissions PP
							LEFT JOIN
							#CoveringPermissions CP
								ON CP.PPID = PP.PPID
						WHERE
							EXISTS (
								SELECT *
								FROM
									#ExpandedChecks EC
								WHERE
										EC.RootClass		= FO.SecurableClass		COLLATE Latin1_General_CI_AI
										AND
										EC.className		= PP.SecurableClass		COLLATE Latin1_General_CI_AI
										AND	
										EC.permissionName	= PP.Permission			COLLATE Latin1_General_CI_AI
								)
							AND
							(	
								PP.scope  IS NULL
									OR
								PP.scope = FO.scope COLLATE Latin1_General_CI_AI
							)
							AND
							PP.SecurableID =  CASE
												WHEN PP.SecurableClass = 'SCHEMA'	THEN FO.SecurableAdditional.value('(./info/SCHEMA/@ID)[1]','int')
												WHEN PP.SecurableClass = 'OBJECT'	THEN FO.SecurableAdditional.value('(./info/OBJECT/@ID)[1]','int')
												ELSE PP.SecurableID
											END	
						) PP
					
					SET @FinalDataSource = '#Final_EffectiveCoverings_Filtered'
			END ELSE BEGIN
				SET @DefaultColumnsList = 'scope,Principal,PrincipalType,PrincipalSource,PrincipalMapped,PrincipalActive,Securable,SecurableType,[Permission],PermissionState,CoverDenied,CoveringsDetails,SourcePath';
				SET @DefaultOrderBy = 'scope,Principal,CoverDenied DESC,PermissionState,SecurableID,MinorID,Securable,PrincipalSource,[Permission]';


				SELECT
					--> Scope info
					DPR.scope

					--> Principal info
					,DPR.Principal	
					,DPR.PrincipalType	
					,DPR.PrincipalSource	
					,DPR.PrincipalSourceType
					,DPR.PrincipalMapped	
					,DPR.PrincipalActive

					--> SecurableName info
					,E.SecurableFull as Securable
					,ISNULL(E.SecurableType,E.SecurableClass) SecurableType
					,SecurableID
					,MinorID
		
					--> Permission info
					,E.[Permission]
					,E.PermissionState
					,CASE E.PStateE
						WHEN 'DENY' THEN 1
						ELSE 0
					END CoverDenied

		
					--> Addiitiona level info
					,E.coveringInfo	 AS CoveringsDetails
		
					--> Additional user info
					,DPR.SourcePath
				INTO
					#Final_EffectiveCoverings
				FROM
					(
						SELECT
							 FPRI.scope
							,FPRI.Principal		
							,FPRI.PrincipalType	
							,FPRI.PrincipalSource
							,FPRI.PrincipalSourceType
							,FPRI.PrincipalMapped
							,~FPRI.is_disabled as PrincipalActive
							,FPRI.SourcePath
						FROM
							#FilteredPrincipals FPRI
					) DPR
					LEFT JOIN
					(
						SELECT
							 PP.*
							,E.coveringInfo
							,E.coveringInfo.value('string((./coverings/SecurableName/U[@state = "DENY"]/@state)[1])','varchar(30)') AS PStateE
							,PP.SecurableAdditional.value('(./info/MINOR/@ID)[1]','int') AS MinorID
						FROM
							#PrincipalsPermissions PP
							LEFT JOIN
							#CoveringPermissions E
								ON PP.PPID = E.PPID
						WHERE
							PP.PermissionUsage = 'FILTERED'
					) E
						ON (E.scope  = DPR.scope OR (DPR.scope IS NULL AND E.scope IS NULL) )
						AND E.PrincipalSource = DPR.PrincipalSource
						AND E.Principal = DPR.Principal
			
				SET @FinalDataSource = '#Final_EffectiveCoverings'
			END

			
	END

	IF @DetailsLevel = 3
	BEGIN
		IF OBJECT_ID('tempdb..#Final_EffectiveAggregated') IS NOT NULL
			DROP TABLE #Final_EffectiveAggregated;

		SET @DefaultOrderBy = 'scope,Principal,Securable,PermissionState DESC';
		SET @DefaultColumnsList = '*';

	

		IF EXISTS(SELECT * FROM #FilteredObjects)
			DELETE FROM #PrincipalsPermissions WHERE SourcePath != 'EFFECTIVE';	 

			SELECT
				 DPR.scope

				--> Principal info
				,DPR.Principal
				,DPR.PrincipalType
				,DPR.PrincipalMapped
				,DPR.PrincipalActive

			--> SecurableName info
			,SecurableFull as Securable
			,SecurableType

			--. Permission info
			,[Permission]
			,PermissionState

			-- Additional info
			,E.coveringInfo as CoveringsDetails
		INTO
			#Final_EffectiveAggregated
		FROM
			(
				SELECT
					 FPRI.scope
					,FPRI.Principal
					,FPRI.PrincipalType
					,FPRI.PrincipalMapped
					,~FPRI.is_disabled			AS PrincipalActive
				FROM
					#FilteredPrincipals FPRI
				WHERE
					FPRI.PrincipalSource = FPRI.Principal --;. Force just Root sources be retrivied.
			) DPR
			LEFT JOIN
			(
				SELECT
					 scope
					,Principal
					,PrincipalType
					,[Permission]
					,SecurableFull
					,ISNULL(SecurableType,SecurableClass) as SecurableType
					,ISNULL(E.CoverDenied,E.PermissionState) as PermissionState
					,PrincipalActive
					,E.coveringInfo

						-- This will assign 1 in this order:  cover denied, same denied, grant with grant, grant
					,ROW_NUMBER() OVER( PARTITION BY scope,Principal,SecurableFull,SecurableType,[Permission] ORDER BY ISNULL(E.CoverDenied,'') DESC, E.PStatePriority) as ShowPriority
				FROM
					(
						SELECT
							PP.*
							,E.coveringInfo
							,CASE PP.PermissionState
								WHEN 'DENY' THEN 1
								WHEN 'GRANT_WITH_GRANT' THEN 2
								ELSE 3
							END as PStatePriority
							,CONVERT(varchar(100),CASE E.coveringInfo.value('string((./coverings/SecurableName/U[@state = "DENY"]/@state)[1])','varchar(30)')
								WHEN 'DENY' THEN 'DENY'
								ELSE NULL
							END) COLLATE Latin1_General_CI_AI CoverDenied
						FROM
							#PrincipalsPermissions PP
							LEFT JOIN
							#CoveringPermissions E
								ON E.PPID = PP.PPID
					) E
				WHERE
					E.PermissionUsage = 'FILTERED'
			) E
				ON (E.scope  = DPR.scope OR (DPR.scope IS NULL AND E.scope IS NULL) OR (DPR.scope IS NULL ))
				AND E.Principal = DPR.Principal
				AND E.ShowPriority = 1
				
			

		

		SET @FinalDataSource = '#Final_EffectiveAggregated';
	END


	SHOW_RESULTS:
		RAISERROR('Formating final data...',0,1) WITH NOWAIT;
		/*
			At this point #FinalData will contains table name with all data.
			The #FinalData must provide all columns specified in documentation.
			This part don't collect more info, just worry about filtering collected values and present data.
		*/
		DECLARE @columnFilters XML;
		SET @columnFilters =	(
					SELECT 
						--'OR '+CONVERT(sysname,REPLACE(FilterType,'COLUMN:','')) +' LIKE '+ QUOTENAME(FT.Filter,'"')
						'AND FD.'+ColumnName+' LIKE '+QUOTENAME(FT.Filter,'"')
							+NCHAR(13)+NCHAR(10) as 'data()'
					FROM 
						(
							SELECT
								FT.*
								,RTRIM(LTRIM(CONVERT(sysname,REPLACE(FilterType,'COLUMN:','')))) as ColumnName
							FROM
								#FilterTable FT
						) FT
					WHERE 
						FilterType like 'COLUMN:%'
					FOR XML PATH(''),TYPE,ROOT('ColumnFilters')
			)

		IF @ProgressLevel >= 6
		BEGIN
			INSERT INTO #DebuggingInfo
			SELECT 'COLUMN_FILTERS_STRING',@columnFilters 

			IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
			BEGIN
				SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
				EXEC sp_executesql @dynQuery;
				DELETE FROM #DebuggingInfo;
			END
		END;


		-- Determining ORDER BY settings...
		IF ISNULL(@OrderBy,'') = ''
			SET @OrderBy = @DefaultOrderBy; --> Default mandatory columns

		IF ISNULL(@ColumnsList,'') = ''
			SET @ColumnsList = @DefaultColumnsList;


		SET @dynQueryFinal = REPLACE(N'

			IF @ProgressLevel >= 6 RAISERROR("Executing final query...",0,1) WITH NOWAIT;

			SELECT
				'+ISNULL(@ColumnsList,'* /*NULL_COLUMNS_LIST*/')+'
			FROM
				'+@FinalDataSource+' FD
			WHERE
				1 = 1
				'+ISNULL(@columnFilters.value('data(.)','varchar(max)'),'')+'
		
			'+ISNULL('ORDER BY
				'+@OrderBy,'/*NULL_ORDER_BY*/'
			)+'
	
		','"','''');

		IF @ProgressLevel >= 6
			BEGIN
				INSERT INTO #DebuggingInfo
				SELECT 'FINAL_QUERY',(select @dynQueryFinal for xml path('FinalQuery'),TYPE)

				IF OBJECT_ID(@DebuggingTable) IS NOT NULL 
				BEGIN
					SET @dynQuery = 'INSERT INTO '+@DebuggingTable+' SELECT *'+ISNULL(','+@DebugExtra,'')+' FROM #DebuggingInfo;'
					EXEC sp_executesql @dynQuery;
					DELETE FROM #DebuggingInfo;
				END
			END;

		IF @ProgressLevel >= 5 RAISERROR('@DetailsLevel is %d. Showing results ...',0,1,@DetailsLevel) WITH NOWAIT;
		EXEC sp_executesql @dynQueryFinal,N'@ProgressLevel int',@ProgressLevel;


	IF EXISTS(SELECT * FROM #Warnings) AND @ProgressLevel >= 1
	BEGIN
		IF @ProgressLevel >= 5 RAISERROR('There are warnings. Showing',0,1) WITH NOWAIT;

		IF @WarningsAsText = 1
		BEGIN
			RAISERROR('------------------------ THERE ARE WARNINGS!!!!! ------------------------',0,1) WITH NOWAIT;

			WHILE EXISTS(SELECT * FROM #Warnings)
			BEGIN
				SELECT TOP 1 @WarningText = MESSAGE FROM #Warnings ORDER BY id

				;WITH Warnings AS ( SELECT TOP 1 MESSAGE FROM #Warnings ORDER BY id)
				DELETE FROM Warnings;
			
				RAISERROR('%s',0,1,@WarningText) WITH NOWAIT;
			END

			RETURN;
		END

		SELECT message AS WARNINGS FROM #Warnings;
	END

/**

THIS IS PROCEDURE DOCUMENTATION!

*DOC:EN-US*-------------------------------------------------------------------------------------------------
sp_WhoIsAuthorized 1.0 (BETA)

THIS DOCUMENTATION IS IN BETA VERSION!
Bugs, criticals, suggestions: mailto:rodrigo@thesqltimes.com
http://scriptstore.thesqltimes.com/docs/whoisauthorized/

.LICENSE 
	sp_WhoIsAuthorized is free to download and use for corporative, educational and personal use.
	

	(C) 2015, Rodrigo Ribeiro Gomes
	www.thesqltimes.com

	This procedure strucutred and documentation was based on sp_WhoIsActive, by Adam Machanic (C) 2007-2011, Adam Machanic
	More info:
		http://sqlblog.com/blogs/adam_machanic/archive/tags/who+is+active/default.aspx

.DESCRIPTION
	This procedure returns permission for one or more principals (database users, logins, roles, server roles).
	sp_WhoIsAuthorized checks all permissions and expand role membership. It also try expand Windows Group membership.
	SQL Server permission hierarchy also is explored by this procedure and high priority permissions and containers is considered when evaluating permissions.

.EXAMPLES

	How return permissions for a user called MyUser
		EXEC sp_WhoIsAuthorized 'MyUser @DB: master msdb';	-- Just master and msdb databases
		EXEC sp_WhoIsAuthorized '@U:MyUser @DB: %';			-- MyUser in all databasess (note you can hide @U prefix)
	
	This example return permissions for any principal (login, roles, users, etc.) which name is 'CONTOSO\Spiderman' on all databases, except master.
		EXEC sp_WhoIsAuthorized 'CONTOSO\Spiderman % -master'		

	Any user, any database
		EXEC sp_WhoIsAuthorized '% @DB:%'; --Any user, any database
		EXEC sp_WhoIsAuthorized '% @DB:% @P:SELECT'; --Any user, any database, just SELECT permissions
		EXEC sp_WhoIsAuthorized '% @DB:% @P:INSERT,UPDATE,DELETE'; --Any user, any database, just INSERT,UPDATE,DELETE
		EXEC sp_WhoIsAuthorized '% @DB:% @PS:CONTROL_SERVER'; -- any database permission, just server permission CONTROL SERVER
		EXEC sp_WhoIsAuthorized '% @DB:% @PD:CONNECT'; -- just CONNECT database permission
		EXEC sp_WhoIsAuthorized '% @DB:% @P:VIEW%'; -- just permissions (Server or database) that starts with VIEW%

	Windows users

		EXEC sp_WhoIsAuthorized 'CONTOSO\BillGates @DB:%,-AppleDB,-GoogleDB';
		EXEC sp_WhoIsAuthorized 'BRAZIL\Joaquim @DB:SambaDB';
		
				
.PARAMETERS

	@Filter
		Filter to be applied. The format is: SOURCE:VALUE1 VALUE2 VALUE% SOURCE2:...
		SOURCE specifies where the filter will be applied.  The supported values are:
			"@U"	- PRINCIPAL (DEFAULT)
			"@DB"	- DATABASE
			"@P"	- PERMISSION (DATABASE OR SERVER)
			"@PS"	- SERVER PERMISSION ONLY
			"@PD"	- DATABASE PERMISSION ONLY
			"[Col]"	- COLUMN (Where col is column returned on resultset)

		COLUMN filters are applied after all data is processed.
		Source that starts with @ are applied on source of data. This can recude data and enchances perfomance.

		Multiple filters can be specified for same source. Don't is need specify the source
		for each filter expression. sp_WhoIsAuthorized will be based on last identified source.
		If the filter starts without a source specified, then the default is used.
		If none valid principal filter is specified then current user is used.
		If none valid database filter is specified, then current database is used.
		

		You can separate multiple filters by ' ' (space)
		Each filter can be in same form as LIKE pattern.
		For specify a literal space, use a counter-slash: '\ ' (without quotes)
		For specify a literal slash as last character of filter, use a two slashs: \\
		If slash isn't last character of your filter, you can specify just one.
		You also can include a "-" (hyphen) for exclude filters.
		
		Ex.: MY_DOMAIN\% USER%
			This example filters any principal (USER,ROLE,LOGIN,etc.) that starts with "MY_DOMAIN\" or with "USER"
			
		Ex.: % -public -sysadmin
			This example filters any principal (USER,ROLE,LOGIN,etc.) except these have name "public" or "sysadmin".

		Ex.: @U:Craig @DB:% -master -tempdb
			This example filters any principal with the name "Craig" on all databases, except master and tempdb.

	@OrderBy

		Specify order of results. Use ColumnNames separate by commas, like in a normal ORDER BY expression.

	@ColumnList

		Columns to be showed. Specify in a comma separated like in a normal SELECT column list.

	@ShowDefaultRoles

		When 1, permissions applied to default roles will be show.
		Note this don't affect source users.
		For more information about source users check description of [PrincipalSource]

	@DetailsLevel

		Control the level of returned information.
		1 - All permissions, without resolve permission hierarchy
		2 - Resolve permission hierarchy (DEFAULT)
		3 - Calculates all effective permissions

	@MembershipLevel

		This controls the level of membership informations collected and calculated.
		sp_WhoIsAuthorized will try get role and windows groups that principals are member of and for nested role membership, it will 
		expands membership up to no more members exists.
		For example, if UserA is in role RoleA and RoleA is in db_datareader, then sp_WhoIsAuthorized will add RoleA and db_datareader (expands)
		as source of permissions for UserA, like SQL Server Engine does in permission check.
		It will try make this for Windows logins and Windows group memebership also.
		For a level that you choose, all levels before are enabled.
		High levels are more slowly that low levels. Be patient.

			0 - No role or windows group membership informations is collected.
			1 - Just expand membership info, without collect any permissions for added roles or groups.
			2 - Collect permissions for added roles and Windows Groups membership 
			3 - Calculate permissions coverings for added roles and groups

	@CoverDeniedOnly

		When 1, then just covering Denied will be collected 
		sp_WhoIsAuthorized will explore SQL Server permission hierarchy, by checking if upper containers of a securable, or cover permission,
		have a denied or granted permission.
		This infomration is used to determine if a permission is effectively granted or no.
		Note this just have a effect when @DetailsLevel >= 2.
		If @MembershipLevel is < 3, then this is applicable just for direct permissions applied to principal.

	@ProgressLevel

		Specify the level of information to print. All levels before selected levels are enabled. For example
		if you choose level 4, levels 0,1,2 and 3 are enabled.

		0 - No WARNING ON DEBUG INFORMATION.
		1 - WARNINGS ONLY (Warings are reported a extra resultset after main results)
		5 - Progress information
		6 - Internal debugging

	@DisableTokenCheck

		When 1 then dont realize the impersonate on a Windows Login or Windows User to get Windows group membership.
		For some set of permissions


	@WarningsAsText

		sp_WhoIsAuthorized will show some warnings when there are. Some error can occurs but procedure can continue executing.
		Warnings will notifies user that results can be incomplete and show reasons and error messages as separate resultset, at the end.

		When 1, then warnings are reported as text, being printed to user, and not showed as separate resultset.
		This is useful when running procedure in multi-server and some server dont generate warnings.

	@DebuggingTable, @DebugExtra

		Internal use. Future compatibility is not guaranted.

	@help

		Shows this help, when value is different of NULL.
		You can specify a language.
		The default is EN-US.
		Possible values:
			1		- USES DEFAULT
			EN-US	- (English-USA)
			PT-BR	- (Portuguese-Brazil)

		
.RESULTSET

	[scope]
		Is scope where permission applied.
		For server permissions, this will contains a NULL.
		For database permissions, this will contains the database name.

	[Principal]
		Principal name.
		Can be a Windows Login, Windows user, role, server role, sql login, etc.

	[PrincipalSource]
		This is principal source of the [Principal] permission.
		For example, if User1 is in role Role1, then [Principal] shows User1, and [PrincipalSource] shows Role1.
		All permissions collected are based on this column.
		For permissions applied directly to [Principal], this column shows the same as [Principal].

	[PrincipalSourceType]
		[PrincipalSource] type. (WINDOWS_LOGIN, WINDOWS_USER, SQL_LOGIN, etc.)
		Check "type_desc" for sys.server_principals or sys.database_principals for all possible values.

	[PrincipalMapped]
		Name of mapped server principal.
		This column generally will be contain some value when the [PrincipalType] is a USER.

	[PrincipalActive]
		When 1, the means the server principal associated with the principal on [PrincipalSource]
		This value is contrary of on sys.server_principals.is_disabled column.

	[SourcePath]
		This value is a graphical representation the relationship between [Principal] and [PrincipalSource].
		For example, consider [Principal] = "User1" and [PrincipalSource] = "Role1". 
		If User1 is in role Role1, then this columns will the text "Role1 --> User1".
		When the [PrincipalSource] is same as [Principal], then this will shows NULL.

	[SecurableName]
		SecurableName. This is object name where the permission [P] was applied.
		If is a column permission, then will show the tableName.ColumnName
		If is a table, but no column permission, then will show tableName.*
		For other types, will show the SecurableName name.
		If procedure cannot detect SecurableName name, it wPerill show "SECURABLE_CLASS: Major_ID.Minor_Id"

	[SecurableType]
		Type of OBJECT when [OClass] = 'OBJECT_OR_COLUMN', like USER_TABLE, STORED_PROCEDURE, etc.
		If [OClass] isn't a object then show class.

	[Permission]
		Permission name.
		Check "permission_name" for sys.database_permissions or "sys.server_permissions" for all possible values

	[PermissionState]
		Permission state.
		Check "state_desc" for sys.database_permissions or "sys.server_permissions" for all possible values
		When @DetailsLevel = 3, then this will show effective state, that's it, the permission inherited by detected cover permissions.
		
	[CoverDenied]
		Indicates if effective permissions state is DENY. This columns will show when @DetailsLevel = 2
		If UserA have a GRANT on  [myDB].[mySchema].[MyTable] but have a DENY on mySchema or myDB, then the effective permission is DENY.
		When a effective permission is DENY, this column will show 1 or otherwise will show 0.

	[CoveringsDetails]
		Covering permission source info. Use to know the source of [DNY].
		This is a XML will all permission the cover current permission.
		You can use this XML for determine the covering permission which DNY is inherited.
		
-------------------------------------------------------------------------------------------------*DOC:EN-US*


*DOC:PT-BR*-------------------------------------------------------------------------------------------------
sp_WhoIsAuthorized 1.0 (BETA)

ESTA DOCUMENTAÇÃO ESTÁ NA VERSÃO BETA!
Bugs, críticas, sugestões: mailto:rodrigo@thesqltimes.com
http://scriptstore.thesqltimes.com/docs/whoisauthorized/

.LICENÇA 
	sp_WhoIsAuthorized é livre para download e uso corporativo, educional ou pessoal.

	(C) 2015, Rodrigo Ribeiro Gomes
	www.thesqltimes.com
	
	Baseada em sp_WhoIsActive, de Adam Machanic (C) 2007-2011, Adam Machanic
	Mais informações:
			http://sqlblog.com/blogs/adam_machanic/archive/tags/who+is+active/default.aspx

.DESCRIÇÃO
	Esta procedure retorna as permissões para um ou mais "principals" (USERS, LOGINS, ROLES, SERVER ROLES).
	sp_WhoIsAuthorized verifica todas as permissões diretas e herdadas através de roles. Ela também tenta identificar os 
	grupos do Windows que um usuário do Windows pertenece.
	A hierarquia de permissões do SQL Server também é explorada por esta procedure e permissões com maior
	prioridade são consideradas quando a procedure está buscando e processando as permissões.
	

.EXEMPLOS

	Como retornar as permissões para um usuário chamado MeuUsuario nos bancos master e msdb:
		EXEC sp_WhoIsAuthorized 'MeuUsuario @DB:master,msdb';		-- Apenas bancos master e msdb
		EXEC sp_WhoIsAuthorized '@U:MeuUsuario @DB:master,msdb';	-- MeuUsuario em todas as bases (pode omitir @U)
	
	Este exemplo retorna as permissões  para qualquer principal cujo nome é 'CONTOSO\Spiderman' em todos os bancos, exceto em master.
		EXEC sp_WhoIsAuthorized 'CONTOSO\Spiderman @DB:% -master'	
		
	Qualquer usuário, qualquer banco
		EXEC sp_WhoIsAuthorized '% @DB:%'; -- Qualquer usuário, qualquer banco
		EXEC sp_WhoIsAuthorized '% @DB:% @P:SELECT'; -- Qualquer usuário, qualquer banco, apenas permissões de SELECT
		EXEC sp_WhoIsAuthorized '% @DB:% @P:INSERT,UPDATE,DELETE'; -- apenas as permissões INSERT,UPDATE,DELETE
		EXEC sp_WhoIsAuthorized '% @DB:% @PS:CONTROL_SERVER'; -- permissões de servidor CONTROL SERVER, qualquer de banco
		EXEC sp_WhoIsAuthorized '% @DB:% @PD:CONNECT'; -- apenas permissão de banco CONNECT
		EXEC sp_WhoIsAuthorized '% @DB:% @P:VIEW%'; -- apenas permissões (Server or database) que começam com VIEW%

	Usuários do Windows

		EXEC sp_WhoIsAuthorized 'CONTOSO\BillGates @DB:%,-AppleDB,-GoogleDB';
		EXEC sp_WhoIsAuthorized 'BRAZIL\Joaquim @DB:SambaDB';

.PARÂMETROS

	@Filter
		
		Filtro a ser aplicado. O formato é: FONTE:VALOR1,VALOR2,VALOR%,FONTE2:...
		FONTE especifica onde o filtro será aplicado. Os valores suportados são:
			"@U"	- PRINCIPAL (PADRÃO)
			"@DB"	- DATABASE
			"@P"	- Permissão tanto para servidor, quanto para banco de dados
			"@PS"	- Permissão a nível de servidor
			"@PD"	- Permissão a nível de banco de dados
			"[Col]"	- COLUNA (Onde col é o nome da coluna retornada)

		Filtros de COLUNA sempre são aplicados após todos os dados serem coletados e processados.
		Filtros que começam com @ são aplicados diretamente na origem do dado. Este tipo de filtro pode contribuir para a perfomance.

		Vários filtros podem ser especificados para a mesma fonte. Não é necessárioe especificar a fonte
		para cada filtro. sp_WhoIsAuthorized irá se basear na última fonte identificada.
		
		Se o filtro começa sem uma fonte especificada, então o padrão é usado.

		Você pode separar vários filtros por ' ' (espaço).
		Você pode especificar como se fosse um filtro LIKE.
		Para especificar um espaço literal, use a contra-barra: '\ '
		Para especificar uma barra no final, use duas contra-barras: \\
		Você também pode incluir um "-" (traço) para filtros de exclusão.

		
		Ex.: MEU_DOMINIO\% USUARIO%
			Este exemplo filtra qualquer principal (USER,ROLE,LOGIN,etc.) que comece com "MEU_DOMINIO" ou com "USUARIO"
			
		Ex.: %,-public -sysadmin
			Este exemplo filtra qualquer principal (USER,ROLE,LOGIN,etc.) exceto estes que possui o nome "public" ou "sysadmin".

		Ex.: @U:Joao @DB:% -master -tempdb
			Este exemplo filtra qualquer principal com o nome "Joao" em todas as bases, exceto master e tempdb.

	@ColumnList

		List de colunas para serem exibidas. Utilize normalmente, como em um SELECT.

	@OrderBy

		Especifica a ordem dos resultados. A sintaxe é a mesma de um ORDER BY comum.

	@ShowDefaultRoles

		Quando 1, as permissões concedidas para os ROLES fixos do SQL Server são exibidas (master,model,tempdb)
		Esteja atento ao fato de que esse parâmetro não afeta usuários-fontes.
		Para mais informações veja a descrição de [PrincipalSource]

	@DetailsLevel

		Controla os detalhes das informações retornadas.
			1 - Todas as permissões, sem resolver a hierarquia.
			2 - Resolve a hierarquia de permissões (PADRÃO)
			3 - Calcula somente as permissões efetivadas

	@MembershipLevel

		Coontrola o nível de informações sobre grupos e roles em que o principal está inserido.
		A sp_WhoIsAuthorized irá tentar obter os roles e grupos do windows os quais um principal é membro.
		A procedure irá respeitar o aninhamento (quando roles estão dentro de outros roles) e tentará ir expandindo isso até o final.
		Por exemplo, se UsuarioA esá na role RoleA e RoleA está em db_datareader, então a procedure irá tentar adicionar 
		RoleA e db_datareader (isto é,expandir) como fonte de permissão para UsuarioA, igual o SQL Server faz.
		Ele irá tentar também verificar os grupos do Windows o qual um login faz parte.
		Todos os nívels anteriores ao nível escolhido são incluídos.
		Quanto maior o nível, mais demorado a query pode executar. Seja paciente.

			0 - Nenhuma informação de roles ou grupos do Windows são coletadas
			1 - Apenas expande os roles e grupos do Windows
			2 - Coleta as permissões para os grupos e roles expandidos
			3 - Explora e calcula a hierarquia de permissões para as roles e grupos adicionados.

	@CoverDeniedOnly

		Quando 1, então apenas permissões com DENY serão analizadas ao resolver a hierarquia de permissões.
		sp_WhoIsAuthorized irá explorar a hierarquia de permissões verificando se os containers  de um securable, ou uma permissão mais elevada,
		tem um DENY ou GRANT.
		Essa informação é usada para determinar se uma permissão está efetivada ou não.
		Note que esta opção tem efeito somente quando @DetailsLevel >= 2
		Se @MembershipLevel´é < 3, então isto é somente aplicável para permissões aplicadas diretamente ao principal.

	@ProgressLevel

		Especifica o nível de informações para exibir. Npuveis anteriores são habilitados.
		Ao escolher um nível, todos os níveis inferiores são incluídos.
		Por exemplo, se você escolher o nível 4, então os níveis 0,1,2 e 3 serão habilitados.

		0 - SEM WARNINGS E/OU QUALQUER INFORMAÇÃO DE DEBUG.
		1 - SOMENTE WARNINGS (Warings são reportados como uma result a parte do resultset principal)
		5 - Informação de progresso
		6 - Uso interno para debugging


	@DisableTokenCheck

		Quando 1, não executa um impersonate em logins do Windows para obter os grupos do Windows.
		Isso desabilita a expansão de grupos do Windows.

	@WarningsAsText

		sp_WhoIsAuthorized irá mostrar alguns avisos quando existirem. Alguns erros podem acontecer mas a procedure poderá
		continuar executando.
		Estes avisos (warnings) irão notificar o usuário que os resultados pode estar incompletos e mostrá as razões e mensagens
		de erro como um resultset separador, no final.

		Quando 1, os avisos são reportados como texto ao invés de serem exibidos como um resultset a parte.
		Isso é útil quando executando a procedure em multi-server e alguns servidores não produzem warnings.

	@DebuggingTable, @DebugExtra

		Uso interno. Compatibilidade futura não é garantida.

	@help

		Quando diferente de nulo, exibe esta ajuda.
		Você pode especificar um idioma.
		O padrão é EN-US.
		Os valores possíveis são:
			1		- USA O PADRÃO
			EN-US	- (Inglês-EUA)
			PT-BR	- (Português-Brasil)

.RESULTSET

	[scope]
		É o escopo de onde as permissões são aplicadas.
		Para permissões a nível de servidor, esta coluna será nula (NULL).
		Para permissões a nível de banco de dados, esta coluna será o nome do banco onde foi coletada.

	[Principal]
		É o nome do principal.
		Pode ser um LOGIN, DATABASE USER, ROLE, SERVER ROLE, LOGIN SQL, etc.

	[PrincipalSource]
		Este é o nome do principal de onde [Principal] está herdando a permissão.
		Por exemplo, se o Usuario1 está na role Role1, então [Principal] irá mostrar "Usuario1", e [PrincipalSource] mostrará Role1.
		Todas as permissões coletadas são baseadas nesta coluna.
		Para permissões aplicadas diretamente à [Principal], então esta coluna irá mostrar o mesmo valor de [Principal].

	[PrincipalSourceType]
		Tipo de [PrincipalSource] (WINDOWS_LOGIN, WINDOWS_USER, SQL_LOGIN, etc.)
		Consulte "type_desc" em sys.server_principals ou sys.database_principals para todos os valores possíveis

	[PrincipalMapped]
		Nome do Server Principal que está mapeado para o principal atual.
		Na maioria dos casos essa coluna terá algum valor quando [PrincipalTyp~e] for algum derivado de "USER".

	[PrincipalActive]
		Quando 1, significa que o server principal associado com o principal em [PrincipalSource] está desativado.
		Este valor sempre será o oposto de sys.server_principals.is_disabled

	[SourcePath]
		Este valor é uma representação gráfica do relacionamento entre [Principal] e [PrincipalSource].
		Por exemplo, considere que [Principal] = "Usuario1" e [PrincipalSource] = "Role1". 
		Se User1 está na role Role1, diretamente, então esta coluna irá mostrar "Role1 --> Usuario1".
		Quando [PrincipalSource] for o mesmo que [Principal], então essa coluna irá ser nula (NULL).

	[SecurableName]
		É o objeto para o qual a permissão foi concedida.
		Se a permissão é uma permissão a nível de coluna, então irá mostrar nomeTabela.nomeColuna
		Se é uma tabela, e não é uma permissão a nível de coluna, então irá mostrar nomeTabela.*
		Para todos os outros tipos, então irá mostrar o nome do objeto, como por exemplo, o nome de um esquema, ou banco de dados.
		Se sp_WhoCanAcess não consegue detectar o nome do objeto, então irá mostrar: "SECURABLE_CLASS: Major_ID.Minor_Id"

	[SecurableType]
		Tipo do objeto when [OClass] = 'OBJECT_OR_COLUMN', como por exemplo USER_TABLE, STORED_PROCEDURE, etc.
		Dependendo da classe, poderá mostrar um sub-tipo. Se a classe for DATABASE_PRINCIPAL, por exemplo, então este poderá ser LOGIN, USER, etc.
		Se sp_WhoIsAuthorized não conseguir determinar o sub-tipo, ou se não houver sub-tipo, então o nome da classe será exibida.

	[Permission]
		Nome da permissão, como por exemplo, SELECT, INSERT, ALTER TRACE, etc.
		Consulte "permission_name" em sys.database_permissions ou "sys.server_permissions" para todos os valores possíveis.

	[PermissionState]
		Estado da permissão
		Consulte "state_desc" para sys.database_permissions ou "sys.server_permissions" para todos os valores possíveis.

	[CoverDenied]
		Indica se ao estado da permissão efetivado é um DENY. Esta coluna só será exibida quando @DetailsLevel = 2.
		Se UsuarioA tem um GRANT de SELECT em [Banco1].[esquema1].[tabela1] mas tem um DENY em Banco1 ou esquema1,
		a permissão efetivada de SELECT em tabela1 é DENY.
		Quando a permissão efetivada é DENY, esta coluna irá mostrar 1 ou, caso contrário, 0.

	[CoverDetails]
		Contém alguns detalhes da fonte de permissão. Utilize para entender de onde vem o valor de [DNY].
		Esta coluna é um XML com todas as permissões que tem maior prioridade sobre a permissão atual.
		Você pode usar este XML para determinar a permissão cover no qual DNY foi herdada.	

-------------------------------------------------------------------------------------------------*DOC:PT-BR*


*/


