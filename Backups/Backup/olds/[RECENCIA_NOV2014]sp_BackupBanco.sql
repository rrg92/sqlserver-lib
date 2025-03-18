/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Uma proc que criei para fazer backup mai fácil!
		Me basiei nas procs do Ola Hallegren, pois em alguns ambientes eu não podia instalar, então fiz essa.


*/
ALTER PROCEDURE [dbo].[sp_BackupBanco]
(
	 @Bancos		NVARCHAR(max)	= ''
	,@Local			NVARCHAR(MAX)	= 'D:\BACKUP\LOG'
	,@CopyOnly		BIT				= 1
	,@Porcentagem	TINYINT			= 10
	,@ExecOpt		TINYINT			= 3
	,@TipoBkp		VARCHAR(15)		= 'LOG'
	,@Comprimir		bit				= 1
)
AS
/*******************************************************************************************************************************                                                       
Descrição  :	Realiza o backup de uma mais bancos.    
				Versões suportadas:
					SQL SERVER 2005 SP1,SP2,SP3	
				Dependências:
					xp_fileexists
					DATABASEPROPERTYEX
					RAISEERROR
Parâmetros :
		@Bancos
			O nome do banco. Pode se especificar mais de um banco separado
			por vírgula. O nome do banco não pode conter vírgulas e nenhum dos símbolos usados para variáveis.
			Algumas variáveis são aceitas:
				$[BANCOS_TODOS]		- Indica que todos os bancos serão incluídos na lista.
				$[BANCOS_USUARIO]	- Indica que todos os bancos de usuário serão inclupidos na lista.
									Os bancos de sistema não.
				$[BANCOS_SISTEMA]	- Indica somente os bancos de sistema.
				-NOME_BANCO			- Indica que o banco em NOME_BANCO não será excluído da lista.
									Esta opção faz com que o banco seja excluido da lista, mesmo que
									tenha sido incluido implicitamente ou explicitamente.
		@Local
			Indica a pasta para onde o(s) backup(s) serão feitos.
		@CopyOnly
			Indica se o backup de log é copy_only(1) ou não(0).
			Backups copy_only não truncam o arquivo de log.
			Padrão: 1
		@Porcentagem
			A porcetagem do progresso que deverá se mostrada para cada banco.
			Padrão: 10 (Indica 10%)
		@ExecOpt
			Opcoes de execucao:
				1(0x1) - Imprimir o código somente
				2(0x2) - Executar e código somente
				3(0x3) - Imprimir e executar.
			Valor padrão: 3

		@Comprimir

				Indica se o backup deve ser compresso ou não.
  
Banco		: master    

HISTÓRICO        
Analista				Data		Abreviação  Descrição                                                        
Rodrigo Ribeiro Gomes	20/08/2011  --			Criou a PROCEDURE.    
**********************************************************************************************************************************/ 

-------------------------------------- ÁREA DE RECURSOS -------------------------------------------------
/*** Área de Recursos: Variávels, temp tables, table variables devem ser escritos aqui. ***/

-- Variáveis
/*
	GLOBAL
		@SQLTmp		--> Irá conter comandos SQL para serem executados dinamicamente.
		@MsgErro	--> Contém alguma mensagem de erro!
		@CodErro	--> Contém algum código de erro!
		@AuxINT		--> Contém algum valor inteiro usado temporariamente pelo script.
		@AuxStr		--> Contém alguma string usada temporiramente pelo script.
		@AuxBIT		--> Contém algum valor do tipo bit usado temporariamente no script!
		@DataAtual	--> Contém o retorno de getDate() em dado momento.
		@DataDMA	--> Contém somente o dia, mês e ano de uma data.
		@DataTempo	--> Contém a parte do tempo de uma data
	
	Quote personalizado
		@DelimE		--> Contém o delimitador da esquerda
		@DelimD		--> Contém o delimitador da direita
		@Separador	--> Contém o separador de dados da string.
		
	Bancos
		@CodBanco	--> Contémo código do banco da tabela #Bancos. Não é o mesmo que o db_id
		@NomeBanco	--> Contém o nome do banco da tabela #Bancos.
		
	Processo de backup
		@NomeArBkp	--> Contém o nome do arquivo de backup
		@OpcoesWITH	--> Contém a cláusula do comando de backup "WITH"

*/
--Copyright
RAISERROR('Backup de Bancos. Por Rodrigo Ribeiro Gomes. RodrigoR.Gomes@hotmail.com',0,0) WITH NOWAIT;

DECLARE
	 @SQLTmp	NVARCHAR(MAX)
	,@MsgErro	NVARCHAR(MAX)
	,@CodErro	INT	
	,@AuxINT	INT
	,@AuxStr	NVARCHAR(MAX)
	,@DelimE	NVARCHAR(MAX)
	,@DelimD	NVARCHAR(MAX)
	,@Separador	NVARCHAR(MAX)
	,@CodBanco	INT
	,@NomeBanco	NVARCHAR(MAX)
	,@NomeArBkp	NVARCHAR(MAX)
	,@DataAtual	DATETIME
	,@DataDMA	NVARCHAR(50)
	,@DataTempo	NVARCHAR(50)
	,@OpcoesWITH NVARCHAR(MAX)
;

-- Tabelas temporárias
/*
	#Erros	: Contém os erros encontrados no script!
	#InfoDir: Armazena os resultados retornados por xp_fileexist.
	#Bancos: Armazena os bancos a serem restaurados.
*/
IF OBJECT_ID('tempdb..#Erros') IS NOT NULL
	DROP TABLE #Erros;
CREATE TABLE #Erros( 
	 seq INT NOT NULL IDENTITY PRIMARY KEY 
	,cod INT NOT NULL DEFAULT 0
	,msg NVARCHAR(MAX) DEFAULT 'Erro Desconhecido' 
);

IF OBJECT_ID('tempdb..#InfoDir') IS NOT NULL
	DROP TABLE #InfoDir;
CREATE TABLE #InfoDir( arquivoExiste BIT,eDiretorio BIT,diretorioPaiExiste BIT );

IF OBJECT_ID('tempdb..#Bancos') IS NOT NULL
	DROP TABLE #Bancos;
CREATE TABLE #Bancos( 
	 cod INT NOT NULL IDENTITY PRIMARY KEY
	,nome NVARCHAR(MAX)
);


-------------------------------------- ÁREA DE SCRIPTS --------------------------------------------------
/*** Área de Scripts: os scrips devem ser escritos aqui. ***/

SET NOCOUNT ON;
---------------- VALIDANDO Os parâmetros

IF @Porcentagem NOT BETWEEN 0 and 100 OR @Porcentagem IS NULL
	SET @Porcentagem = 10
IF @CopyOnly IS NULL
	SET @CopyOnly = 1;

---------------- MONTANDO A TABELA COM OS BANCOS
--> Verificando a variável que contém os bancos!
IF @Bancos IS NULL OR LEN(@Bancos) = 0 BEGIN
	SET @MsgErro = N'Nenhum banco informado.';
	INSERT INTO #Erros(msg) VALUES(@MsgErro);
	GOTO MOSTRA_ERROS;
END

--> O script abaixo irá varrer a string com os bancos, e para cada banco informado, irá gerar um INSERT INTO. (Usando Quote pernsonalizado)
SET @DelimE = N'INSERT INTO #Bancos(nome) VALUES(N'+NCHAR(0x27);
SET @DelimD = NCHAR(0x27)+N')';
SET @Separador = N','
SET @SQLTmp = @DelimE+REPLACE(@Bancos,@Separador,@DelimD+N';'+@DelimE)+@DelimD 

INSERT INTO
	#Bancos
EXEC(@SQLTmp)

-- Removendo espaços indesejados.
UPDATE 
	#Bancos
SET
	nome = RTRIM(LTRIM(nome))
	
----- INTERPRETANDO AS VARIÁVEIS

--> $(BANCOS_*)
INSERT INTO
	#Bancos(nome)
SELECT
	d.name
FROM
	sys.databases d
WHERE 
(
	EXISTS (SELECT	* FROM #Bancos WHERE nome = '$[BANCOS_TODOS]')
)	
OR (
	EXISTS (SELECT	* FROM #Bancos WHERE nome = '$[BANCOS_USUARIO]')
	AND
	d.database_id > 4
)
OR (
	EXISTS (SELECT	* FROM #Bancos WHERE nome = '$[BANCOS_SISTEMA]')
	AND
	d.database_id <= 4
)
	
-- Removendo nomes duplicados! 
;WITH BancosTmp AS
(
	SELECT DISTINCT
		 b.cod
		 --> Gera uma sequencia. Bancos com o mesmo nome, terão mais do que uma linha, e o valor da coluna será maior que 1.
		,ROW_NUMBER() OVER( PARTITION BY b.nome ORDER BY b.cod ) as Rn
	FROM
		#bancos b
)
DELETE FROM #Bancos WHERE cod IN ( SELECT cod FROM BancosTmp WHERE Rn > 1 );

--> Removendo os bancos que devem ser ingorados (o nome começa com um -)
;WITH BancosIngorados AS
(
	SELECT
		RIGHT(nome,LEN(nome)-1) as NomeBanco --> Remove o '-' para poder usar o nome no WHERE do DELETE abaixo
	FROM
		#Bancos
	WHERE
		Nome like '-%'
)
DELETE FROM #Bancos WHERE Nome IN (SELECT NomeBanco FROM BancosIngorados);

--> Removendo os bancos com nomes de variável
DELETE FROM #Bancos WHERE Nome like '$\[BANCOS_%\]' ESCAPE '\'
DELETE FROM #Bancos WHERE Nome like '-%'

---------------- VALIDANDO O DIRETÓRIO DOS LOGS
--> Verificando se o diretório informado existe!
IF @Local IS NULL OR LEN(@Local) = 0 BEGIN
	SET @MsgErro = N'A variável @Local é nula ou vazia';
	INSERT INTO #Erros(msg) VALUES(@MsgErro);
	GOTO MOSTRA_ERROS;
END
--> Verificando se existe uma barra no final. Se tiver remove-a
IF RIGHT(@Local,1) in ('\','/')
	SET @Local = LEFT(@Local,LEN(@Local)-1)

SET @SQLTmp = 'EXEC xp_fileexist '+QUOTENAME(@Local,NCHAR(0x27))

INSERT INTO
	#InfoDir
EXEC(@SQLTmp)

SELECT
	@AuxINT = eDiretorio
FROM
	#InfoDir
	
IF @AuxINT = 0 BEGIN --> Diretório não existe.
	SET @MsgErro = N'O diretório '+QUOTENAME(@Local,NCHAR(0x27))+' não foi encontrado!';
	INSERT INTO #Erros(msg) VALUES(@MsgErro);
	GOTO MOSTRA_ERROS;
END

---------------- PERCORRENDO A TABELA DE BANCOS, MONTANDO O SCRIPT DE BACKUP, E EXECUTANDO OU PRINTANDO.
SELECT 
  @DataAtual	= GETDATE()
 ,@DataDMA		= CONVERT( VARCHAR(10),@DataAtual,103 )
 ,@DataTempo	= CONVERT( VARCHAR(12),@DataAtual,114 )
 ,@AuxStr		= @DataDMA + ' '+@DataTempo
RAISERROR('Iniciando processo de backup. Data: %s',0,0,@AuxStr) WITH NOWAIT;
RAISERROR('',0,0) WITH NOWAIT;

IF EXISTS(
	SELECT * FROM #Bancos
)
BEGIN --> Início do script para percorrer os bancos

	SET @CodBanco = 0;
	
	WHILE EXISTS (
			SELECT * FROM #Bancos WHERE cod > @CodBanco
		) OR @CodBanco = 0
	BEGIN --> Inicio Loop para percorrer os bancos
	
		SELECT TOP 1
			 @CodBanco	= b.cod
			,@NomeBanco	= b.nome
		FROM
			#Bancos b
		WHERE
			cod > @CodBanco
			
		RAISERROR('Banco: %s',0,0,@NomeBanco) WITH NOWAIT;
	
		IF DB_ID(@NomeBanco) IS NULL BEGIN
			SET @AuxStr = QUOTENAME(@NomeBanco,CHAR(0x27))
			RAISERROR('O Banco %s não existe',0,0,@AuxStr) WITH NOWAIT;
			GOTO CONTINUAR_LOOP;
		END
		

		IF CAST( DATABASEPROPERTYEX(@NomeBanco,'Recovery') AS VARCHAR(MAX)) = 'SIMPLE' AND @TipoBkp = 'LOG' BEGIN
			SET @AuxStr = QUOTENAME(@NomeBanco,CHAR(0x27))
			RAISERROR('O Banco %s está no modo SIMPLE.',0,0,@AuxStr) WITH NOWAIT;
			GOTO CONTINUAR_LOOP;
		END
		
		--> Determinando a extensão do backup
		DECLARE
			@Extensao varchar(100)

		SET @Extensao = CASE @TipoBkp
							WHEN 'LOG' THEN 'trn'
							WHEN 'FULL' THEN 'bak'
						END

		--> Montando o nome do arquivo
		SELECT 
		  @DataAtual	= GETDATE()
		 ,@DataDMA		= CONVERT( VARCHAR(10),@DataAtual,103 )
		 ,@DataTempo	= CONVERT( VARCHAR(5),@DataAtual,114 ) --> utilizei varchar(8) para remover a partr de segundo e milésimos.
		 ,@NomeArBkp	= @NomeBanco+'_'+@TipoBkp+'_'+REPLACE(@DataDMA,'/','')+'_'+REPLACE(@DataTempo,':','')+'.'+@Extensao;
	
		--> Montando as opcoes WITH
		SET @OpcoesWITH = N''+
			 ISNULL('STATS = '+CONVERT(VARCHAR(3),@Porcentagem),'')
				+
			CASE @CopyOnly WHEN 1 THEN ',COPY_ONLY' ELSE '' END
				+
			CASE @Comprimir WHEN 1 THEN ',COMPRESSION' ELSE '' END
			
		DECLARE
			@BackupType varchar(100)

		SET @BackupType = CASE @TipoBkp
							WHEN 'LOG' THEN 'LOG'
							WHEN 'FULL' THEN 'DATABASE'
						END

		IF @BackupType IS NULL
			SET @BackupType = 'LOG'
		

		SET @SQLTmp = N''+
			'BACKUP '+@BackupType+' '+@NomeBanco
				+
			' TO DISK = '+QUOTENAME(@Local+'\'+@NomeArBkp,CHAR(0x27))
				+
			ISNULL(' WITH '+@OpcoesWITH,'')

		
		--> Verificando as opções de execução
		/*
			Cada bit da variável @ExecOpt reprsenta uma opção.
			Valores dispoíveis:
				Bit 0 | 00000001 | 0x1
					Imprimir somente	
				Bit 1 | 00000010 | 0x2
					Executar somente
		*/
		IF @ExecOpt & 0x1 > 0	--> Bit 0 ativo
			RAISERROR('%s',0,0,@SQLTmp) WITH NOWAIT;
		IF @ExecOpt & 0x2 > 0	--> Bit 1 ativo
			EXEC(@SQLTmp);
		
	
		CONTINUAR_LOOP: --> Este trecho irá fazer algumas ações antes de verificar se existe banco...
		RAISERROR('',0,0) WITH NOWAIT;
	END --> Fim do loop para percorrer os bancos

SELECT 
  @DataAtual	= GETDATE()
 ,@DataDMA		= CONVERT( VARCHAR(10),@DataAtual,103 )
 ,@DataTempo	= CONVERT( VARCHAR(12),@DataAtual,114 )
 ,@AuxStr		= @DataDMA + ' '+@DataTempo
RAISERROR('Processo de backup finalizado. Data: %s',0,0,@AuxStr) WITH NOWAIT;
RAISERROR('',0,0) WITH NOWAIT;
RAISERROR('',0,0) WITH NOWAIT;

END --> Fim do script para percorrer os bancos
	

-------------------------------------- ÁREA DE TRATAMENTO --------------------------------------------------
MOSTRA_ERROS:
	IF EXISTS(
			SELECT * FROM #Erros
		) 
	BEGIN --> Inicio do script para exibir os erros!
		
		SET @AuxINT = 0 --> Representa a chave primária da tabela de erros!!!!!
		
		WHILE EXISTS( --> Irá pecorrer a tabela. A cada iteração passa por um "seq" diferente
				SELECT * FROM #Erros e WHERE e.seq > @AuxINT
			)
			BEGIN --> Incio do loop para exibir cada erro na tabela
			
				SELECT TOP 1
					 @AuxINT	= e.seq
					,@MsgErro	= e.msg
					,@CodErro	= e.cod
				FROM
					#Erros e
				WHERE
					e.seq > @AuxINT
			
				RAISERROR('Cod: %d Erro: %s',16,1,@CodErro,@MsgErro) WITH NOWAIT;
				
			
			END --> Fim do loop para exibir cada erro na tabela
		
	END --> Fim do script para exibir erros!
