/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Script para fazer o restore de todos os bancos.
		Foi um dos primeiro que criei, então, deve ter muita coisa pra melhorar!
		MAs deixei aqui, pela ideia!


*/


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
		,TDEThumbprint			varbinary(32) --> Não tem pra versão 2005
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
	INNER JOIN	msdb.dbo.backupmediafamily	bmf	on	bmf.media_set_id = bs.media_set_id
WHERE
		bs.type				= 'D'	
	AND bs.backup_finish_date in --> Faz o filtro somente pelo último backup de cada banco
		(
			SELECT
				max( bsex.backup_finish_date  )
			FROM
				msdb.dbo.backupset bsex
			WHERE
					bsex.database_name	= bs.database_name
				and	bsex.type			= bs.type	
		)
	and database_name not in ('master','tempdb','model','msdb')
	and database_name not like 'ReportServer%'
	and database_name not like 'Tunnig%'

	
DECLARE
	 @proxBD			bigint
	,@maxBD				bigint
	,@nomeBD			sysname
	,@NomeBackup		varchar(200)
	,@cmdCriar			nvarchar(200)
	,@DirBackups		varchar(100)
	,@CaminhoRestore	varchar(200)
	,@DestinoBackup		varchar(max)
	,@CaminhoBdAtual	varchar(max)
	,@SQLRestore		varchar(max)	
	,@ProxArquivoBD		int
	,@MaxArquivoBD		int
	,@NomeArLogico		varchar(500)
	,@NomeArBanco		varchar(500)
	,@MsgStatus			varchar(500)	
	
--> Inicializando as variáveis
SELECT
	  --> Contador que determinará o banco atual a ser restaurado
	  @proxBD			= 1		
	  --> O máximo que @proxBD pode assumir		
	 ,@maxBD			= MAX( ordem )
	 --> Contador para cada arquivo do banco de dados.
	 ,@ProxArquivoBD	= 1
	  --> O diretório onde ficam os Arquivos de Backups
	 ,@DirBackups		= 'C:\Backups'
	 --> O diretório onde ficarão os arquivos de cada banco
	 ,@DestinoBackup	= 'C:\Program Files\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQL\DATA\'	
FROM
	@Bancos

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
	EXEC sp_executesql N'RESTORE FILELISTONLY FROM DISK = @Caminho',N'@Caminho varchar(300)',@CaminhoRestore
		
	--> Obtendo a maior ordem dos arquivos do banco
	SELECT 
		@MaxArquivoBD	= MAX( Ordem )
	FROM
		@ResultadoFileListOnly	
		
	 --> Conterá o comando de RESTORE de cada banco
	 SELECT @SQLRestore = ''
		
	--Montando a query com as opções de MOVE
	WHILE @ProxArquivoBD <= @MaxArquivoBD
	BEGIN
		SELECT
			 @NomeArLogico	= LogicalName
			,@NomeArBanco	= master.dbo.fnNomeArquivo( PhysicalName ) 
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
			 REPLACE
			,STATS = 10
			,'+@SQLRestore+'

		ALTER DATABASE
			'+@nomeBD+'
		SET 
			MULTI_USER;
	';
	
	SELECT @MsgStatus = 'Iniciando RESTORE do Banco '+@nomeBD+' do arquivo:  '+@CaminhoRestore+'... '
	RAISERROR(@MsgStatus, 0, 1) WITH NOWAIT	
	--PRINT 'Iniciando RESTORE do Banco '+@nomeBD+' do arquivo:  '+@CaminhoRestore+'... ';
		
	EXEC(@SQLRestore);
		
	DELETE FROM @ResultadoFileListOnly;
		
	SELECT @proxBD = @proxBD + 1;
END