/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		PRoc para restaurar um banco!
		Criei inicialmente para restaurar de um servidor de prod em dev (tinha um linkedserver no script).
		Tirei e deixei para futuras melhorias.


*/

USE master
GO

ALTER PROCEDURE prcRestaurarBanco
(  
	 @NomeDoBanco	sysname  
	,@MoverPara		varchar(500)	= 'C:\DirRestore'
	,@BackupsDir	varchar(500)	= 'C:\BackupsSQL' -- Produção  
	,@Porcentagem	int				= 10  
	,@TempoDeEspera datetime		= '00:00:35' 
	,@DataDoBackup	datetime		= NULL
	,@Recovery		varchar(100)	= 'RECOVERY'
	,@TipoBkp		char(1)			= 'D'
)  
AS  
/*
	Criado Por Rodrigo Ribeiro Gomes

	Permite que um banco seja restaurado.
	Parâmetros:
		@NomeDoBanco	=	O Nome do Banco a ser restaurado. Se não existir, nada será feito.
		@MoverPara		=	Indica o caminho para o qual os arquivos do banco serão movidos.
							Se NULL for especificado, será preservado o caminho contido no 
							arquivo de backup. O padrão é NULL
		@BackupsDir		=	Indica o diretório onde se encontra os arquivos de backup.
							Informe sempre uma pasta compartilhada, pois em servidores
							remotos, esta procedure poderá nao encontrar o caminho.
							O padrão é a pasta de backups FULL de produção
		@Procentagem	=	Indica de quanto em quanto será exibida a porcentagem
							de sucesso da restauração. O padrão é 10%.
		@DataDoBackup	=	Indica a data limite para a procura do backup.
							A procedure irá sempre procurar o último backup FULL
							antes desta data informada. A procedure considera as horas,minutos e segundos
							no calculo da data. O padrão é a a data atual.
							Ex.: 
								BACKUP A - 1/12/2010 ás 02:00:00	
								BACKUP B - 5/12/2010 ás 10:00:00
								BACKUP C - 8/12/2010 ás 02:00:00
					
								Se @DataDoBackup = '4/12/2010' Então será utilizado o BACKUP A 
								Se @DataDoBackup = '8/12/2010' Então será utilizado o BACKUP C 
								Se @DataDoBackup = '5/12/2010' Então será utilizado o BACKUP A
								Se @DataDoBackup = '5/12/2010 23:59:59' Então será utilizado o BACKUP B
	
	Modificações:

		Responsável		Data		Abreviação			Comentários
		Rodrigo			09/12/2010	RRG09122010			Criação do parâmetro da data.
	
*/
	SET DATEFORMAT dmy; ---> RRG09122010

	IF @DataDoBackup IS NULL
		SET @DataDoBackup = getDate();

	DECLARE  
		@Bancos TABLE ( ordem int primary key identity, NomeBD sysname,  NomeBackup varchar(200) )
	  
	DECLARE --> Tabela que receberá os resultado do EXEC no FILELISTONLY  
		@ResultadoFileListOnly TABLE  
		(  
			 Ordem					int				PRIMARY KEY IDENTITY  
			,LogicalName			nvarchar(128)  
			,PhysicalName			nvarchar(260)  
			,Type					char(1)  
			,FileGroupName			nvarchar(128)  
			,Size					numeric(20,0)  
			,MaxSize				numeric(20,0)  
			,FileID					bigint  
			,CreateLSN				numeric(25,0)  
			,DropLSN				numeric(25,0)  
			,UniqueID				uniqueidentifier  
			,ReadOnlyLSN			numeric(25,0)  
			,ReadWriteLSN			numeric(25,0)  
			,BackupSizeInBytes		bigint  
			,SourceBlockSize		int  
			,FileGroupID			int  
			,LogGroupGUID			uniqueidentifier  
			,DifferentialBaseLSN	numeric(25,0)  
			,DifferentialBaseGUID	uniqueidentifier  
			,IsReadyOnly			bit  
			,IsPresent				bit  
			--  ,TDEThumbprint   varbinary(32) --> Não tem pra versão 2005  
		) --> Baseado em http://msdn.microsoft.com/en-us/library/ms173778.aspx  

	INSERT INTO   
		@Bancos  
		(   
			 NomeBD  
			,NomeBackup  
		)  
	SELECT DISTINCT --> Obtem a lista de BACKUPS mais recente de cada banco  
		 database_name  
		,right(physical_device_name,CHARINDEX('\',REVERSE(physical_device_name))-1) as NomeBackup  
	FROM  
					msdb.dbo.backupset			bs  
		INNER JOIN	msdb.dbo.backupmediafamily bmf on bmf.media_set_id = bs.media_set_id  
	WHERE  
			bs.type					= @TipoBkp  
		AND bs.backup_finish_date	in --> Faz o filtro somente pelo último backup de cada banco  
									(  
										SELECT  
											max( bsex.backup_finish_date  )  
										FROM  
											msdb.dbo.backupset bsex  
										WHERE  
												bsex.database_name		 = bs.database_name  
											and bsex.type				 = bs.type   
											and bsex.backup_finish_date <= @DataDoBackup ---> RRG09122010
									)   
		AND database_name = @NomeDoBanco  

	------------------------------------------- AVISO  
	DECLARE  
	@VarData varchar(20)  
	SET @VarData = CONVERT(varchar,getDate(),14)  

	RAISERROR('Data de Inicio: %s', 0,1,@VarData ) WITH NOWAIT  
	RAISERROR('ATENÇÃO: ', 0, 1) WITH NOWAIT   
	RAISERROR('Você irá atualizar o banco de dados: %s', 0, 1,@NomeDoBanco) WITH NOWAIT   
	RAISERROR('A atualização irá afetar todos os dados do banco.', 0, 1) WITH NOWAIT   
	RAISERROR('Certifique-se que o nome do banco está correto.', 0, 1) WITH NOWAIT   

	SET @VarData = CONVERT(varchar,getDate()+@TempoDeEspera,14)  
	RAISERROR('Você ainda pode cancelar esta operação.',0,1) WITH NOWAIT  
	RAISERROR('O sistema irá aguardar seu cancelamento até %s', 0, 1,@VarData) WITH NOWAIT  
	WAITFOR DELAY @TempoDeEspera  
	RAISERROR('O processo de Restauração será iniciado... Qualquer tentativa de cancelamento poderá implicar em resultados inesperados',0,1) WITH NOWAIT  
	------------------------------------------- AVISO  

	DECLARE  
		 @proxBD   bigint  
		,@maxBD    bigint  
		,@nomeBD   sysname  
		,@NomeBackup  varchar(200)  
		,@cmdCriar   nvarchar(200)  
		,@DirBackups  varchar(100)  
		,@CaminhoRestore varchar(200)  
		,@DestinoBackup  varchar(max)  
		,@CaminhoBdAtual varchar(max)  
		,@SQLRestore  varchar(max)   
		,@ProxArquivoBD  int  
		,@MaxArquivoBD  int  
		,@NomeArLogico  varchar(500)  
		,@NomeArBanco  varchar(500)  
		,@MsgStatus   varchar(500)   

	--> Inicializando as variáveis  
	SELECT  
		--> Contador que determinará o banco atual a ser restaurado  
		@proxBD   = 1    
		--> O máximo que @proxBD pode assumir    
		,@maxBD   = MAX( ordem )  
		--> Contador para cada arquivo do banco de dados.  
		,@ProxArquivoBD = 1  
		--> O diretório onde ficam os Arquivos de Backups  
		,@DirBackups  = @BackupsDir  
		--> O diretório onde ficarão os arquivos de cada banco  
		,@DestinoBackup = @MoverPara   
	FROM  
		@Bancos  

	IF @Recovery NOT IN ('RECOVERY','NORECOVERY')
	BEGIN
		RAISERROR('Valor de @Recovery incorreto. Alterando para ''RECOVERY'' ', 0, 1) WITH NOWAIT
		SET @Recovery = 'RECOVERY'
	END

	WHILE @proxBD <= @maxBD -- Enquanto nao passar do ultimo banco  
	BEGIN  

		SELECT  
			 @nomeBD		= nomeBD  
			,@NomeBackup	= NomeBackup  
		FROM  
			@Bancos  
		WHERE  
			ordem = @proxBD  

		-- Se o banco não existe, então cria-o  
		IF DB_ID(@nomeBD) IS NULL BEGIN  
			SELECT  
				@cmdCriar = N'Use master; CREATE DATABASE '+@nomeBD  

			EXEC sp_executesql @cmdCriar  

			print 'Criado '+@nomeBD
		END  

		-- Montando o caminho do Restore  
		SELECT  
			@CaminhoRestore = @DirBackups+@NomeBackup  

		--> Obtendo a lista de arquivos do banco  
		INSERT INTO   
			@ResultadoFileListOnly  
		EXEC 
			sp_executesql N'RESTORE FILELISTONLY FROM DISK = @Caminho',N'@Caminho varchar(300)',@CaminhoRestore  

		--> Obtendo a maior ordem dos arquivos do banco  
		SELECT   
			@MaxArquivoBD = MAX( Ordem )  
		FROM  
			@ResultadoFileListOnly   

		--> Conterá o comando de RESTORE de cada banco  
		SELECT @SQLRestore = ''  

		--Montando a query com as opções de MOVE  
		WHILE @ProxArquivoBD <= @MaxArquivoBD AND @MoverPara IS NOT NULL  
		BEGIN  
			SELECT  
				 @NomeArLogico = LogicalName  
				,@NomeArBanco  = right(PhysicalName,CHARINDEX('\',REVERSE(PhysicalName))-1) 
			FROM   
				@ResultadoFileListOnly  
			WHERE  
				Ordem = @ProxArquivoBD  

			SELECT @SQLRestore = @SQLRestore + ' MOVE '+quotename(@NomeArLogico,'''')+' TO '+quotename(@DestinoBackup+@NomeArBanco,'''')  

			SET @ProxArquivoBD = @ProxArquivoBD + 1  

			--> Checando se o loop irá repetir. Se sim, coloca a vígula.  
			IF @ProxArquivoBD <= @MaxArquivoBD   
				SELECT @SQLRestore = @SQLRestore + ','  
		END  

		--> Montando o comando do RESTORE  
		SELECT @SQLRestore = '  
			USE master;  

			ALTER DATABASE  
				'+@nomeBD+'  
			SET   
				SINGLE_USER  
			WITH   
				ROLLBACK IMMEDIATE;  

			RESTORE DATABASE  
				'+@nomeBD+'  
			FROM  
				DISK = '''+@CaminhoRestore+'''  
			WITH  
				REPLACE,  
				STATS = '+CAST(@Porcentagem AS varchar(3))+'  
				'+CASE WHEN @MoverPara IS NULL THEN '' ELSE ','+@SQLRestore END+'
				,'+@Recovery+' 

			ALTER DATABASE  
				'+@nomeBD+'  
			SET   
				MULTI_USER;  
		';  

		SELECT @MsgStatus = 'Iniciando RESTORE do Banco '+@nomeBD+' do arquivo:  '+right(@CaminhoRestore,CHARINDEX('\',REVERSE(@CaminhoRestore))-1) +'... '  
		RAISERROR(@MsgStatus, 0, 1) WITH NOWAIT   
		RAISERROR('Não interrompa a execução, pois o banco poderá ficar indisponível', 0, 1) WITH NOWAIT   
		--PRINT 'Iniciando RESTORE do Banco '+@nomeBD+' do arquivo:  '+@CaminhoRestore+'... ';  

		EXEC(@SQLRestore);  

		DELETE FROM @ResultadoFileListOnly;  

		SELECT @proxBD = @proxBD + 1;  
	END