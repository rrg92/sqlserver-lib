/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Esse script foi um esboço inicial para carregar eventos de um arquivo do Extended Events em partes.
		Ler um arquivo .xel, do extended events, com apenas T-SQL, pode ser bem lento e demorado dependendo do tamanho do arquivo.
		O objetivo principal aqui é carregar vários arquivos em partes, permitindo parar o script rápido se precisar, sem fazer um rollback longo
		
		Eu tinha deixado os comentários em ingles pra praticar (perceba pelos diversos errors, rs), mas vou tentar resumir a ideia aqui.
		O algoritmo que usei é relativemente simples:
			- Pega o proximo arquivo a ser lido (na ordem em que foi gerado pelo XE)
			- Ler os top X eventos desse arquivo.. Repetir enquanto nao chegou no final do arquivo 
			- Se chegou no final, recomeça (ate que acabem os arquivos)
			
		Apesar de serem poucos passos, obter o próximo arquivo e checar se ainda tem , requerem algiuns pequenos hacks com as fucnoes de ler arquivo do XE.
		No geral, funciona bem, mas eu tenho uma vaga lembrança de algum problema (ou gera duplicado, ou pode acabar excluindo alguns eventos, não lembro exato o que era). Não seria todos os casos, mas é bom saber que existe essa chance... 
		
		Você precisa só preencher as variáveis @BasePath (onde estao os seus arquivos do extended events, *.xel) e @DestinationTable (a tabela de destino).
		
		Obviamente, cabem várias melhorias aqui no script. Algum dia eu melhoro (ou alguém com mais tempo que eu).
*/

DECLARE
		@Path sysname
		,@BasePath sysname
		,@BaseFileName sysname
		,@IsLinux bit = 0
		,@DirSeparator char(1)
		,@LastFile nvarchar(1000)
		,@LastOffset bigint
		,@LastTimeStamp datetime2
		,@SQL nvarchar(max)
		,@VersionNum decimal(10,6)
		,@DestinationTable sysname 
		,@TopRows int = 1000
	;

	SET @BasePath = 'F:\Traces\First\*.xel';
	SET @DestinationTable = '##TestImport';


	SELECT TOP 0 
		EventXML = CONVERT(XML,E.event_data)
		,E.file_name
		,E.file_offset
		,timestamp_utc = CONVERT(datetime2,NULL)
	INTO #EventXML 
	FROM sys.fn_xe_file_target_read_file(@Path,null,null,null) E
	
	CREATE CLUSTERED INDEX IxCluster ON #EventXML(file_name,file_offset);
	
	WHILE 1 = 1
	BEGIN

		IF OBJECT_ID('tempdb..#Events') IS NOT NULL
			DROP TABLE #Events;

		TRUNCATE TABLE #EventXML;

		RAISERROR('Getting next %d rows of %s',0,1,@TopRows,@Path) WITH NOWAIT;
		-- Load next set of events...
		-- Again: Due to TOP, we need filter all events in a file (not use offset and inital file)
		--	Up to sql 2019, if a use init file, i must use offset.. .but because can exists more events in same offset (due TOP), we need read all file
		INSERT INTO 
			#EventXML
		SELECT TOP(@TopRows)
			E.EventXML
			,E.file_name
			,E.file_offset
			,E.EventXML.value('(event/@timestamp)[1]','datetime2') 
		FROM
			(SELECT	
				*
				,EventXML = CONVERT(XML,E.event_data)
			FROM 
				sys.fn_xe_file_target_read_file(@Path,null,null,null) E
			) E
		OPTION(RECOMPILE)
		
		-- If returned no rows, then this can means reached end of current file and processed all events from last timestamp.
		IF NOT EXISTS(SELECT * FROM #EventXML)
		BEGIN
			RAISERROR('	Now rows returned from this file.',0,1) WITH NOWAIT;
			-- If we have a last file to check, then 
			-- we will check If there are another file, this query will update "@Path" to the next one.
			-- The case where @LastFile is null is when the Destination table is empty and loop iterate first time.
			--		If not event was generared, it will enter in this path...
			IF @LastFile IS NOT NULL
			BEGIN
				RAISERROR('	Checking if there are next file from %s, offset %I64d, Base:%s',0,1,@LastFile,@LastOffset,@BasePath) WITH NOWAIT;
				SELECT TOP 1
					@Path = file_name 
				FROM 
					sys.fn_xe_file_target_read_file(@BasePath,null,@LastFile,@LastOffset) E

				IF @@ROWCOUNT != 0
					CONTINUE;
			END

			-- If this is last file available, then no row will be returned... 
			-- In this case, we dont have nothing more to do... End the loop...
			BREAK;
		END ELSE BEGIN
			-- If rows available, lets update the last file and offset returned...
			-- We will use this data next iteration of this loop
			SELECT TOP 1
				@LastTimeStamp	= DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), E.timestamp_utc)
				,@LastFile		= file_name
				,@Path			= file_name
				,@LastOffset	= file_offset
			FROM 
				#EventXML  E
			ORDER BY 
				file_name desc,file_offset desc,timestamp_utc DESC
		END

		
		RAISERROR('Parsing EventXML (table #Events)',0,1) WITH NOWAIT;
		SELECT 
			 EventTime			= E.EventXML.value('(event/@timestamp)[1]', 'datetime2')
			,EventName			= E.EventXML.value('(event/@name)[1]', 'varchar(200)')
			,EventSequence		= E.EventXML.value('(event/action[@name="event_sequence"]/value)[1]', 'int')

			,session_id			= E.EventXML.value('(event/action[@name="session_id"]/value)[1]', 'int')
			,DatabaseName		= E.EventXML.value('(event/action[@name="database_name"]/value)[1]', 'sysname')
			,SqlText			= ISNULL(
									NULLIF(E.EventXML.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)'),'')
									,E.EventXML.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)')
								)
			,DurationMs			= CONVERT(decimal(20,2),E.EventXML.value('(event/data[@name="duration"]/value)[1]', 'decimal(20,2)')/1000)
			,CpuMs				= CONVERT(decimal(20,2),E.EventXML.value('(event/data[@name="cpu_time"]/value)[1]', 'decimal(20,2)')/1000)
			,LogicalReads		= E.EventXML.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint')
			,PhysicalReads		= E.EventXML.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint')
			,Writes				= E.EventXML.value('(event/data[@name="writes"]/value)[1]', 'bigint')
			,RowCounts			= E.EventXML.value('(event/data[@name="row_count"]/value)[1]', 'bigint')
			,UserName			= E.EventXML.value('(event/action[@name="username"]/value)[1]', 'sysname')
			,LoginName			= E.EventXML.value('(event/action[@name="server_principal_name"]/value)[1]', 'sysname')
			,InstanceName		= E.EventXML.value('(event/action[@name="server_instance_name"]/value)[1]', 'nvarchar(200)')
			,ClientPid			= E.EventXML.value('(event/action[@name="client_pid"]/value)[1]', 'int')
			,ClientHostname		= E.EventXML.value('(event/action[@name="client_hostname"]/value)[1]', 'nvarchar(500)')
			,ConnectionId		= E.EventXML.value('(event/action[@name="client_connection_id"]/value)[1]', 'uniqueidentifier')
			,AppName			= E.EventXML.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(1000)')
			,SystemThreadId		= E.EventXML.value('(event/action[@name="system_thread_id"]/value)[1]', 'int')
			,SchedulerId		= E.EventXML.value('(event/action[@name="scheduler_id"]/value)[1]', 'int')
			,NumNodeId			= E.EventXML.value('(event/action[@name="numa_node_id"]/value)[1]', 'int')
			,CpuId				= E.EventXML.value('(event/action[@name="cpu_id"]/value)[1]', 'int')
			,Result				= E.EventXML.value('(event/data[@name="result"]/value)[1]', 'varchar(100)')
			,DtLoad				= GETDATE()
			,EvtFile			= E.file_name
			,EvtOffset			= E.file_offset
		INTO
			#Events
		FROM
			#EventXML E
		OPTION(MAXDOP 1)



		IF OBJECT_ID(@DestinationTable,'U') IS NULL
		BEGIN
			SET @SQL = 'SELECT TOP 0 * INTO '+@DestinationTable+' FROM #Events;'
			SET @SQL+= 'CREATE CLUSTERED INDEX IxCluster ON '+@DestinationTable+'(EventTime)';
			SET @SQL += 'WITH (DATA_COMPRESSION = PAGE)';

			RAISERROR('	Creating destination table...',0,1) WITH NOWAIT;
			exec(@SQL);
			IF @@ERROR != 0 RETURN;
		END

		RAISERROR('	Loading data into destination table...',0,1) WITH NOWAIT;
		SET @SQL = 'INSERT INTO '+@DestinationTable+' SELECT * FROM #Events';
		EXEC(@SQL);

		IF @@ERROR != 0
			RETURN


	END