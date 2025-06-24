/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Essa é uma proc que criei para o Power Alerts.
		Pelo menos, uma das primeiras versoes... Serve pra improtar xevents de pouco em pouco para uma tabela.
		Ja nao atualizo ela tem tempo e a versão atual do power alerts tem melhorias.
		Mas, de qualquer maneira, resolvi deixar aqui (com autorização da Power Tuning).
		Recomendo que use o power alerts, se quiser uma solução completa pro seu banco: https://poweralerts.com.br
*/
ALTER PROCEDURE
	stpPowerAlert_ImportXEvent(
		 @XeSession nvarchar(1000)
		,@DestinationTable nvarchar(100)
		,@Columns XML
		,@Debug bit = 0
		,@EventNameCol nvarchar(200)	= 'Nm_Event'
		,@EventTsCol nvarchar(200)		= 'Dt_Event'
		,@IncludeEventData bit			= 0
		,@AutomaticDestTable bit		= 1 -- If table have 1 AutoCol, then create tables from xml.
														-- If table dont have auto col, then use data types from table...
		,@StopStart	bit					= 0
		,@topEvents int					= 10000
	)	
AS
	SET NOCOUNT ON;
	IF OBJECT_ID('tempdb..#PowerAlert_Debug') IS NOT NULL 
		SET @Debug = 1
	
	DECLARE
		@filenamePattern nvarchar(1000)
		,@metaPattern nvarchar(1000)
		,@CurrentFile nvarchar(1000)
		,@CurrentOffset int
		,@DirName nvarchar(1000)
		,@StartTime datetime
		,@EndTime datetime
		,@FileImportStartTime datetime
		,@FileImportEndTime datetime
		,@TotalTime int
		,@InsertColList nvarchar(max)
		,@AutomaticTableMode varchar(100)
		,@spsql nvarchar(max)
		,@sql nvarchar(max)
		,@XeCol nvarchar(max)
		,@evtDataColTEmplate nvarchar(1000) = 'e.XeEventData.value(''#XPATH'',''#TYPE'')'
		,@evtDataXmlTemplate nvarchar(1000) = 'e.XeEventData.query(''#XPATH'')'
		,@BaseFileName nvarchar(1000)
	;

	SELECT 
		@filenamePattern = REPLACE(CONVERT(nvarchar(1000),value),'.xel','_0_*.xel') 
		,@BaseFileName = RIGHT(@filenamePattern, CHARINDEX('\', REVERSE(@filenamePattern) )  - 1)
	FROM 
		sys.server_event_sessions AS [session]
	JOIN sys.server_event_session_targets AS [target]
	  ON [session].event_session_id = [target].event_session_id
	JOIN sys.server_event_session_fields AS field 
	  ON field.event_session_id = [target].event_session_id
	  AND field.object_id = [target].target_id	
	WHERE
		field.name = 'filename'
		and [session].name= @XeSession

	IF @@ROWCOUNT = 0 
		RETURN 1;
		
	IF @Debug = 1 RAISERROR('	Base Dir: %s, BAseName: %s',0,1,@filenamePattern,@BaseFileName) WITH NOWAIT;


	SET @DirName = LEFT(@filenamePattern,LEN(@filenamePattern)-CHARINDEX('\',REVERSE(@filenamePattern)))

	IF OBJECT_ID('tempdb..#EventData') IS NOT NULL DROP TABLE #EventData;
	CREATE TABLE #EventData(XeEventData XML, SrcFile nvarchar(1000))


	IF OBJECT_ID('tempdb..#FileList') IS NOT NULL DROP TABLE #FileList;
	CREATE TABLE #FileList(Id int not null identity primary key,FilePath nvarchar(2000), depth int, IsFile int)

	INSERT INTO #FileList(FilePath,depth,IsFile)
	EXEC master.sys.xp_dirtree @DirName,1,1

	DELETE FROM #FileList WHERE FilePath NOT LIKE '%'+@BaseFileName+'_0_%.xel'
	
	declare @Id int = -1;

	IF @StopStart = 1
	BEGIN
		SET @sql = 'ALTER EVENT SESSION '+QUOTENAME(@XeSession)+' ON SERVER STATE = STOP';	
		
		

		IF EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name = @XeSession)
		BEGIN
			IF @Debug = 1 RAISERROR('	Stopping event session: %s',0,1,@sql) WITH NOWAIT;
			EXEC(@sql);
		END
	END


	IF @Debug = 1
		RAISERROR('	All data imported in %d ms',0,1, @TotalTime) WITH NOWAIT;

	-- Load list of colmns....
	DECLARE @XeCols TABLE(
		 ColId int identity
		,ColName nvarchar(300) UNIQUE
		,MainExpr nvarchar(2000)
		,ExprType nvarchar(500)
		,AlternateExpr XML
		,DestCol nvarchar(300) UNIQUE
	)
	
	DECLARE @DestTableColumnTypes TABLE(ColName sysname, ColType nvarchar(300));
	DECLARE
		@DestTableDb sysname
		,@DestTableName sysname


	IF LEFT(@DestinationTable,1) = '#'
		SELECT @DestTableDb = 'tempdb', @DestTableName = @DestinationTable
	ELSE
		SELECT @DestTableDb = PARSENAME(@DestinationTable,3), @DestTableName = ISNULL(quotename(PARSENAME(@DestinationTable,2)),'.')+quotename(PARSENAME(@DestinationTable,1))

	set @spsql = @DestTableDb+'..sp_executesql';

	IF @AutomaticDestTable = 1
	BEGIN
		set @sql = 'SELECT 
				C.name 
				,T.name+CASE
					WHEN T.name LIKE ''%char%'' THEN ''(''+ISNULL(CONVERT(varchar(10),NULLIF(C.max_length,-1)),''max'')+'')''
					WHEN T.name IN (''numeric'',''decimal'') THEN ''(''+CONVERT(varchar(10),C.precision)+'',''+CONVERT(varchar(10),C.scale)+'')''
					ELSE ''''
				END
			FROM sys.columns C 
				INNER JOIN
				sys.types T
					ON T.system_type_id = C.system_type_id
			WHERE object_id = OBJECT_ID(@TableName)'

		insert into @DestTableColumnTypes
		exec @spsql @sql,N'@TableName nvarchar(500)',@DestTableName
	END

	insert into @XeCols(ColName,AlternateExpr,ExprType,DestCol) values('EventTs','''<x>(event/@timestamp)[1]</x>''','datetime','Dt_Event')
	insert into @XeCols(ColName,AlternateExpr,ExprType,DestCol) values('EventName','<x>(event/@name)[1]</x>','nvarchar(30)','Nm_Event')

	IF @IncludeEventData = 1
		insert into @XeCols(ColName,AlternateExpr,ExprType,DestCol) values('EventXML','<x>.</x>','XML','EventXML')


	IF @Debug = 1 RAISERROR('	Mergin columnst list...',0,1) WITH NOWAIT;

	MERGE
		@XeCols D
	USING (
		SELECT
			ColName				= C.x.value('@name','nvarchar(300)')
			,MainExpr			= C.x.value('@x','nvarchar(2000)')
			,ExprType			= COALESCE(C.x.value('@type','nvarchar(500)'),CT.ColType)
			,AlternateExpr		= C.x.query('./x')
			,DestCol			= ISNULL(C.x.value('@dest','nvarchar(500)'),C.x.value('@name','nvarchar(300)'))
		FROM
			@Columns.nodes('col') C(x)
			LEFT JOIN
			@DestTableColumnTypes CT
				ON CT.ColName =  ISNULL(C.x.value('@dest','nvarchar(500)'),C.x.value('@name','nvarchar(300)')) COLLATE DATABASE_DEFAULT
	) S
		ON S.ColName = D.ColName
	WHEN NOT MATCHED THEN
		INSERT(ColName,MainExpr,ExprType,AlternateExpr,DestCol)
		VALUES(S.ColName,S.MainExpr,S.ExprType,S.AlternateExpr,S.DestCol)
	WHEN MATCHED THEN
		UPDATE SET DestCol = S.DestCol
	;

	-- null type columns...
	DECLARE @NullCols nvarchar(max);

	SET @NullCols = STUFF((SELECT ','+ColName FROM @XeCols WHERE ExprType IS NULL FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,'')

	IF @NullCols IS NOT NULL
	BEGIN
		RAISERROR('Columns %s dont have a defined data type. Check if mapping names ir correct or use automatic table.',16,1, @NullCols);
		RETURN;
	END

	IF @AutomaticDestTable = 1 AND EXISTS(SELECT * FROM @DestTableColumnTypes HAVING COUNT(*) = 1 AND COUNT(CASE WHEN ColName = '_auto_' THEN ColName END) = 1) 
		SET @AutomaticTableMode = 'RecreateTable' 

	IF @AutomaticTableMode = 'RecreateTable'
	BEGIN
		SET @sql = 'ALTER TABLE '+@DestTableName+' ADD '+STUFF((
			SELECT ','+quotename(DestCol)+' '+ExprType 
			FROM @XeCols
			ORDER BY ColId
			FOR XML PATH(''),TYPE
		).value('.','nvarchar(1000)'),1,1,'')
		+' ALTER TABLE '+@DestTableName+' DROP COLUMN _auto_;'

		SET XACT_ABORT ON;
		BEGIN TRAN;
			EXEC @spsql @sql;
		COMMIT;
	END
		

	IF @Debug = 1
		SELECT * FROM @XeCols
		


	
	IF @Debug = 1 RAISERROR('	Building xe event cols...',0,1) WITH NOWAIT;

	SET @XeCol = STUFF((
		SELECT
			','+QUOTENAME(ISNULL(DestCol,ColName))+' = '+ISNULL(REPLACE(
											' COALESCE(
												NULL
												'+AlternateXPaths+'
											)'

										,'#TYPE',ExprType),'NULL')
		FROM
			@XeCols c
			OUTER APPLY (
				SELECT	
					AlternateXPaths = T.sx.value('.','nvarchar(max)')
				FROM (
					select 
						','+CASE 
								WHEN UPPER(ExprType) = 'XML' THEN REPLACE(@evtDataXmlTemplate,'#XPATH',ExprPath)   
								ELSE REPLACE(@evtDataColTEmplate,'#XPATH',ExprPath)   
							END
					from (
							SELECT
								ExprPath	= NULLIF(x.p.value('data(.)','nvarchar(1000)'),'')
								,ExprOrder	= NULLIF(x.p.value('@order','int'),'')
							FROM c.AlternateExpr.nodes('x') x(p)
						) XP
					WHERE
						XP.ExprPath IS NOT NULL
					ORDER BY
						ExprOrder
					FOR XML PATH(''),TYPE
				) T(sx)
			) S
		ORDER BY
			c.ColId
		FOR XML PATH(''),TYPE
	).value('.','nvarchar(max)'),1,1,'')


	IF @Debug = 1 RAISERROR('	Building insert col list...',0,1) WITH NOWAIT;

	SET @InsertColList = STUFF((
		SELECT 
			','+DestCol
		FROM
			@XeCols
		ORDER BY 
			ColId
		FOR XML PATH(''),TYPE
	).value('.','nvarchar(max)'),1,1,'')


	IF @Debug = 1
	BEGIN
		RAISERROR('PowerAlertImportXeEvent: InsertColList: %s',0,1,@InsertColList) WITH NOWAIT;
	END

	SET @sql = '
		
		'+ISNULL('INSERT '+@DestinationTable+'('+@InsertColList+')','')+'

		SELECT
			'+@XeCol+'
		FROM
			#EventData e

	'

	IF @Debug = 1
	BEGIN
		RAISERROR(' IMPORT SQL: %s',0,1,@sql) WITH NOWAIT;
	END

	DECLARE @RunError int,@RunRows int, @ErrorMsg nvarchar(1000)

	
	
	WHILE 1 = 1
	BEGIN
		SELECT TOP 1 
			@CurrentFile = @DirName+'\'+FilePath 
			,@Id = Id
		FROM 
			#FileList
		WHERE
			Id > @Id
		ORDER BY
			Id

		IF @@ROWCOUNT = 0 BREAK;
		
		SET @metaPattern = REPLACE(@CurrentFile,'.xel','.xem');
		SET @metaPattern = @DirName+'\*.xem'
		IF @Debug = 1 RAISERROR('	Importing File %s (top %d events)',0,1, @CurrentFile, @topEvents) WITH NOWAIT;
		SET @FileImportStartTime = GETDATE()
		INSERT INTO
			#EventData
		SELECT top(@topEvents)
			F.event_data
			,F.file_name
		FROM 
			sys.fn_xe_file_target_read_file ( @CurrentFile,@metaPattern, null, null)  as F
		SET @FileImportEndTime = GETDATE()
		SET @TotalTime = DATEDIFF(MS,@FileImportStartTime,@FileImportEndTime);

		IF @Debug = 1 RAISERROR('	File %s, imported in %d ms',0,1,@CurrentFile, @TotalTime) WITH NOWAIT;


		IF @Debug = 1 RAISERROR('		Running import sql...',0,1) WITH NOWAIT;
		BEGIN TRY
			SET @StartTime = GETDATE(); 
			EXEC sp_executesql @sql
			SET @EndTime = GETDATE();
		END TRY
		BEGIN CATCH
			set @RunError = ERROR_NUMBER();
			set @ErrorMsg = ERROR_MESSAGE();

			IF @RunError = 2389
				RAISERROR('Error 2398 when running dynamic sql... Review the xpath expressions or data type choosen is correct. USe @Debug = 1 to inspect output sql... Original msg: %s',16,1,@ErrorMsg)
			ELSE
				RAISERROR(@ErrorMsg,16,1);

			return;
		END CATCH
		
		SET @TotalTime = DATEDIFF(MS,@StartTime,@EndTime);
		IF @Debug = 1 RAISERROR('		Running Done! Total time: %d ms',0,1,@TotalTime) WITH NOWAIT;

	END
	
	IF @StopStart = 1
	BEGIN
		SET @sql = 'ALTER EVENT SESSION '+QUOTENAME(@XeSession)+' ON SERVER STATE = START';
		
		IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name = @XeSession)
		BEGIN
			IF @Debug = 1 RAISERROR('	Starting event session: %s',0,1,@sql) WITH NOWAIT;
			EXEC(@sql);
		END
	END

	
	RETURN 0;


