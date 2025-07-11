/*#info 

	# Autor 
		Luciano Caixeta Moreira (Luti) e Rodrigo Ribeiro Gomes
	
	# Descrição 
		Em um período que trabalhei como Luti, fizemos essa proc para alguma rotina.
		Não lembro se chegamos a usar, mas uma rápida olhada no script parece estar pronta.
		Creio que hoje há rotinas melhores para essa coleta, mas deixo aqui para futuras referências.


*/

/********************************************************************************************************************************************
	Autor: Luciano Caixeta Moreira
	Data criação: 31/08/2011
	Descrição:
	
	Última atualização: 
	Responsável última atualização:
	
	Histórico de alterações:	
		Rodrigo Ribeiro Gomes	- Revisão/Finalização do script.

	Descrição
		Salva as informações de fragmentação, retornadas pela função 'sys.dm_db_index_physical_stats', em uma tabela, ou apenas exibe-as.
		Quando a opção de salvar em tabela for escolhida, deve se tomar cuidado com a versão do SQL, pois dependendo da mesma, as colunas
		podem mudar.
		Além de salvar os dados retornados pela função, a procedure irá salvar a data em que a coleta foi realizada, e este valor será
		o mesmo todas as linhas inseridas, a cada chamada da procedure.
	Dependências
		Tabelas/Views:
			#1 - sys.tables
			#2 - sys.indexes
			#3 - sys.partitions
		Funções/Procedures
			#1 - sys.dm_db_index_physical_stats
		Referências
			#1 - http://msdn.microsoft.com/en-us/library/ms188917.aspx (Consulte outras versões se necessário.)
		Comandos
			Nenhuma
			
	Versões suportadas
		SQL Server 2005
		SQL Server 2008 (inclusive R2)
		
	Parâmetros
		@BancoDados
			É o banco de dados do qual se deseja obter os dados. Se NULL for especificado, então todos os bancos
			serão consultados.
				
		@TabelaDestino
			É a tabela para onde jogar os dados. A estrutura dessa tabela depende da versão do SQL.
			Se a tabela não existir, o a procedure irá criar a mesma, com a estrutura de acordo com a versão do SQL em que a mesma está sendo executada.
			Se este parâmetro for NULL, então a procedure apenas ira exibir os resultados.
			
		@NomeEsquema
			Se for especificado um valor diferente de NULL, então somente as tabelas desse schema serão incluídas na pesquisa.
			Se NULL for especificado, todos os schemas serão considerados.
			
		@NomeObjeto
			É o nome da tabela que se deseja buscar os dados de fragmentação.
			Se NULL for passado, então todas as tabelas serão consideradas.
			
		@IndexID
			É o ID do indice cujo os dados de fragmentação serão obtidos.
			Se NULL for especificado, então todos os índices serão consultados. (De cada tabela.)
			
		@PartitionNumber
			É o número da partição a ser filtrado. Se NULL for especificado, todas as partições serão consideradas.
			
		@FonteInfoTabelas
			É o nome da tabela que contém as meta-informações das tabelas existentes.
			Para evitar processamento extra na busca das informações de certas tabelas, você pode usar este parâmetro.
			Se já possuir uma tabela com os dados das tabelas requeridas, basta especificar a query no parâmetro.
			Você pode espeficiar qualquer comando que possa ser usado dentro de uma expressao de tabela.
			Se o parâmetro for NULL, a procedure consulta as tabelas 'sys.tables','sys.indexes' e 'sys.partitions' para
			obter as tabelas necessárias.
			A estrutura da expressao de tabela, inclusive nomes de colunas, deve ser a seguinte:
				Nome				Tipo		Descrição
				DatabaseID			int			O ID do banco de dados!
				ObjectID			int			O ID do objeto!
				NomeTabela			sysname		O nome da tabela
				SchemaName			sysname		O nome do schema da tabela.
				IndexID				int			O ID do índice.
				PartitionNumber		int			o ID da partição a qual o índice da tabela pertence.
				
			
		@Modo
			É o modo de pesquisa a ser usado na função 'sys.dm_db_index_physical_stats'.
			O valor padrão é LIMITED.
			
		HISTÓRICO
		Desenvolvedor				Abreviação			Data			Descrição
		Rodrigo Ribeiro Gomes			--				25/11/2011		Criação da PROCEDURE.
********************************************************************************************************************************************/
IF OBJECT_ID('proc_ColetarInfoFragmentacao') IS NOT NULL
	DROP PROCEDURE proc_ColetarInfoFragmentacao;
GO

CREATE PROCEDURE  proc_ColetarInfoFragmentacao
(
	 @BancoDados		varchar(100)	= NULL
	,@TabelaDestino		varchar(100)	= NULL
	,@NomeEsquema		varchar(100)	= NULL
	,@NomeObjeto		varchar(100)	= NULL
	,@IndexID			int				= NULL
	,@PartitionNumber	int				= NULL
	,@FonteInfoTabelas	varchar(3000)	= NULL
	,@Modo				varchar(20)		= 'LIMITED'
)
AS
BEGIN
	--> Parâmetros para teste
	--DECLARE
	--	 @BancoDados		varchar(100)	= NULL
	--	,@TabelaDestino		varchar(100)	= NULL
	--	,@NomeEsquema		varchar(100)	= NULL
	--	,@NomeObjeto		varchar(100)	= NULL
	--	,@IndexID			int				= NULL
	--	,@PartitionNumber	int				= NULL
	--	,@FonteInfoTabelas	varchar(100)	= NULL
	--	,@Modo				varchar(20)		= 'LIMITED'
		
	--> Recursos Necessários

	---------- RECURSOS ----------
	-- Tabelas temporárias
	IF OBJECT_ID('tempdb..#InfoTabelasBD') IS NOT NULL
		DROP TABLE #InfoTabelasBD;
		
	/** Esta tabela irá conter os dados das tabelas (partições e índices) cujo 
	a informação de fragmentação devera ser obtida. **/
	CREATE TABLE
	#InfoTabelasBD
	(
		 OrdemSeq			int IDENTITY CONSTRAINT pkInfoTabelaBD PRIMARY KEY
		,DatabaseID			int
		,ObjectID			int
		,IndexID			int
		,PartitionNumber	int
	);
		
	--> Esta tabela conterá o resultado da coleta, caso seja necessário.
	IF OBJECT_ID('tempdb..#IPS') IS NOT NULL
		DROP TABLE #IPS;

	-- Variáveis
	DECLARE
		 @Comando_SQL			nvarchar(max)
		,@FonteTabelasInfo_SQL	nvarchar(max)
		,@colDatabaseID			int
		,@colObjectID			int
		,@colIndexID			int
		,@colPartitionNumber	int
		,@colOrdemSeq			int
		,@DataColeta			datetime
		,@MostrarColeta			bit
		
	---------- SCRIPTING ----------
	 --> Colocando a data de coleta em um variável para ser a mesma para todos os inserts feitos.
	SET @DataColeta = GETDATE();

	--> Verificando se a coleta deve ser exibida.
	SET @MostrarColeta = 0;
	IF @TabelaDestino IS NULL
		SET @MostrarColeta = 1;
		

	--> Se for NULL atribui a ?, pois esta variável será usada junto com a procedure sp_MSforeachdb.
	IF @BancoDados IS NULL	--> Se for NULL atribui a ?, pois esta variável será usada junto com a procedure sp_MSforeachdb.
		SET @BancoDados = '?';
		
	/** A fonte de informações de tabelas é uma query que a procedure usará
	para obter as informações das tabelas. Se o usuário já tiver uma tabela com essas informações
	deverá especificar o nome, caso contrário deve deixar o parâmetro '@FonteInfoTabelas' como NULL, para que a procedure
	busque essas informações das tabelas do sistema. **/
	IF @FonteInfoTabelas IS NULL	
		--> O usuário nao informou uma fonte, então a query abaixo será usada!
		SET @FonteTabelasInfo_SQL = N'SELECT DISTINCT
									 DB_ID()			AS	DatabaseID
									,T.object_id		AS	ObjectID
									,T.name				AS	NomeTabela
									,S.name				AS	SchemaName
									,I.index_id			AS	IndexID
									,P.partition_number	AS	PartitionNumber
								FROM
												sys.tables		T	WITH(NOLOCK)
									INNER JOIN	sys.indexes		I	WITH(NOLOCK)	ON	I.object_id = T.object_id
									INNER JOIN	sys.schemas		S	WITH(NOLOCK)	ON	S.schema_id	= T.schema_id
									INNER JOIN	sys.partitions	P	WITH(NOLOCK)	ON	P.object_id = T.object_id
																					AND P.index_id	= I.index_id'
	ELSE BEGIN
		--> Montando o comando a ser usado.
		SET @FonteTabelasInfo_SQL = 'SELECT * FROM '+@FonteInfoTabelas;
	END

	/** Este é o comando SQL que irá inserir os dados das tabelas (de todos os bancos ou não)
	na tabela temporária #InfoTabelasBD. A query abaixo será executada na procedure sp_MSforeacdb.
	o IF serve para impedir que a query seja executada para outros bancos, quando um banco especifico for informado.
	A lógica do IF é a seguinte:
		IF DB_NAME() NOT IN ('NomeBanco') AND @NomeBanco <> '?'
			RETURN;
	O INT é utilizado para futuras alteração que envolvam uma lista de bancos que não serão permitidos!**/
	SET @Comando_SQL = N'
		USE '+@BancoDados+N'

		-- Verifica se o banco do loop atual deve ser considerado. (? = Se a variável @Bancos)
		IF DB_NAME() NOT IN ('+QUOTENAME(@BancoDados,CHAR(0x27))+N') AND '+QUOTENAME(@BancoDados,NCHAR(0x27))+N' <> '+QUOTENAME(N'?',NCHAR(0x27))+N'
			RETURN;

		INSERT INTO
			#InfoTabelasBD(DatabaseID,ObjectID,IndexID,PartitionNumber)
		SELECT
			  D.DatabaseID
			 ,D.ObjectID
			 ,D.IndexID
			 ,D.PartitionNumber
		FROM
			(
				'+@FonteTabelasInfo_SQL+'
			) D
		WHERE
			1 = 1 --> Coloquei este para não precisar fazer verificações de AND
			'+COALESCE('AND D.NomeTabela = '+QUOTENAME(@NomeObjeto,NCHAR(0x27)),N'')+N'
			'+COALESCE('AND D.SchemaName = '+QUOTENAME(@NomeEsquema,NCHAR(0x27)),N'')+N'
			'+COALESCE('AND D.IndexID = '+CONVERT(varchar(5),@IndexID),'')+N'
			'+COALESCE('AND D.PartitionNumber = '+CONVERT(varchar(5),@PartitionNumber),'')+N'
	'
	EXEC sp_MSforeachdb @Comando_SQL;

	--> Inicializando
	SET @colOrdemSeq	= 0;
	SET @colDatabaseID	= 0;

	--> Se a procedure deve retornar os dados, então inicializa a tabela que conterá os mesmos.
	IF @MostrarColeta = 1 BEGIN
		SELECT 
			*,@DataColeta as DataColeta
		INTO
			#IPS
		FROM 
			sys.dm_db_index_physical_stats(NULL,NULL,NULL,NULL,NULL)
		WHERE
			1 = 2;
			
		SET @TabelaDestino = '#IPS';
	END ELSE BEGIN
		IF OBJECT_ID(@TabelaDestino) IS NULL BEGIN --> Se a tabela não existe, então a cria.
			SET @Comando_SQL = N'
				SELECT 
					*,@DataColeta as DataColeta
				INTO
					'+@TabelaDestino+N'
				FROM 
					SYS.dm_db_index_physical_stats(NULL,NULL,NULL,NULL,NULL)
				WHERE
					1 = 2;
			'
			
			EXEC sp_executesql @Comando_SQL,N'@DataColeta datetime',@DataColeta;
		END
	END

	WHILE EXISTS
	(
		SELECT
			 *
		FROM 
			#InfoTabelasBD IT
		WHERE
			IT.OrdemSeq > @colOrdemSeq
	)
	BEGIN

		SELECT TOP 1
			 @colOrdemSeq			= IT.OrdemSeq
			,@colDatabaseID			= IT.DatabaseID
			,@colObjectID			= IT.ObjectID
			,@colIndexID			= IT.IndexID
			,@colPartitionNumber	= IT.PartitionNumber
		FROM 
			#InfoTabelasBD IT
		WHERE
			IT.OrdemSeq > @colOrdemSeq
		ORDER BY
			IT.OrdemSeq ASC
		
		
		SET @Comando_SQL = N'
			INSERT INTO
				'+@TabelaDestino+'
			SELECT 
				*
				,@DataColeta 
			FROM 
				sys.dm_db_index_physical_stats
				('+CONVERT(varchar(10),@colDatabaseId)+N'
				,'+CONVERT(varchar(10),@colObjectId)+N'
				,'+CONVERT(varchar(10),@colIndexId)+N'
				,'+CONVERT(varchar(10),@colPartitionNumber)+N'
				,@Modo
				)
			;
		'
		
		EXECUTE sp_executesql @Comando_SQL,N'@DataColeta datetime, @Modo varchar(20)',@DataColeta, @Modo;

	END

	IF @MostrarColeta = 1
		SELECT * FROM #IPS;
	
END