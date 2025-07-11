/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Mais uma versão que criei de procedure para gerar o create de index no 2005.
		
		
*/

/********************************************************************************************************************************************
	Descrição
		Gera o CREATE INDEX de um dado índice.
	Dependências
		Tabelas/Views:
			#1 - sys.indexes
			#2 - sys.filegroups
			#3 - sys.index_columns
			#4 - sys.columns
			#5 - sys.partition_schemes
			#6 - sys.stats	
		Funções/Procedures
			Nenhuma
		Referências
			#1 - http://msdn.microsoft.com/en-us/library/ms188783(v=sql.90).aspx
		Comandos
			Nenhuma
			
	Versões suportadas
		SQL Server 2005
		
	Parâmetros
		@NomeObjeto
			É o nome da tabela onde o índice está.
			
		@NomeIndice
			É o nome do índice cujo se irá gerar o seu comando CREATE.
			
		@SORT_IN_TEMPDB
			Opção SORT_IN_TEMPDB do comando CREATE INDEX.
			Consulte a referência #1 para mais informações.
			
		@DROP_EXISTING
			Opção DROP_EXISTING do comando CREATE INDEX.
			Consulte a referência #1 para mais informações.
			
		@ONLINE
			Opção ONLINE do comando CREATE INDEX.
			Consulte a referência #1 para mais informações.
			
		@MAXDOP
			Opção MAXDOP do comando CREATE INDEX.
			Consulte a referência #1 para mais informações.
			
		@DataSpace
			Indica um nome de um filegroup, ou partition scheme, para onde mover o índice.
			Se este parâmetro for NULL, a função irá gerar o comando no filegroup padrão.
			Caso contrário, a função irá verificar se o filegroup, ou partiton scheme, existe no banco de dados.
			Se não existir este parâmetro será ignorado.
			Se existir, a função irá gerar o CREATE no dataspace atual, isto é, filegroup ou partition scheme, 
			além de gerar a opção DROP_EXISTING, como ON.
			
		HISTÓRICO
		Desenvolvedor				Abreviação			Data			Descrição
		Rodrigo Ribeiro Gomes			--				13/12/2011		Criação da FUNÇÃO.
		Rodrigo Ribeiro Gomes		RRG27032012-01		27/03/2012		Correção do modo como a ordem das colunas
																		dentro do índice é verificada.
********************************************************************************************************************************************/

IF object_id('dbo.fnGeraCreateIndice2005') IS NOT NULL
	DROP FUNCTION dbo.fnGeraCreateIndice2005
GO

CREATE FUNCTION dbo.fnGeraCreateIndice2005
(
	 @NomeObjeto		varchar(400)
	,@NomeIndice		varchar(400)
	,@SORT_IN_TEMPDB	varchar(3)		= 'OFF'
	,@DROP_EXISTING		varchar(3)		= 'OFF'
	,@ONLINE			varchar(3)		= 'OFF'
	,@MAXDOP			varchar(3)		= '0'
	,@DataSpace		varchar(500)	= NULL
)
RETURNS VARCHAR(MAX)
AS
BEGIN
--> Configuráveis pelo usuário
--DECLARE
--	 @NomeObjeto			varchar(400)
--	,@NomeIndice		varchar(400)
--	,@SORT_IN_TEMPDB	varchar(3)
--	,@DROP_EXISTING		varchar(3)
--	,@DataSpace		varchar(3)
--	,@MAXDOP			varchar(3)
--SET @NomeObjeto			= 'alunos'
--SET @NomeIndice		= 'alunos_pk'
--SET @SORT_IN_TEMPDB = 'OFF'
--SET @DROP_EXISTING	= 'OFF'
--SET @DataSpaceLINE			= 'OFF'
--SET @MAXDOP			= '0'

--> Extraindo somente o nome do partition scheme, se for o caso.
DECLARE
	@NomePartitionScheme varchar(max), @PosicaoParenteses smallint
	
SET	@PosicaoParenteses		= CHARINDEX('(',@DataSpace)-1;

IF @PosicaoParenteses <= 0
	SET @NomePartitionScheme = NULL;
ELSE
	SET @NomePartitionScheme = RTRIM(LTRIM(LEFT(@DataSpace,@PosicaoParenteses)));

--> Checando  o filegroup informado existe.
IF NOT EXISTS
	(
		SELECT 1 FROM sys.filegroups FG WHERE FG.name = @DataSpace
		UNION ALL
		SELECT 1 FROM sys.partition_schemes PS WHERE PS.name = @NomePartitionScheme
		) 
	--> Se não existe, então deixa o mesmo OFF.
BEGIN
	SET @DataSpace = NULL;
END ELSE BEGIN
	--> Se existe, então força automaticamente a opção DROP_EXISTING ser ON
	SET @DROP_EXISTING = 'ON';
END

DECLARE
	@SQLFinal	varchar(max)

SELECT
	@SQLFinal = 'CREATE '
		--> UNIQUE ?
		+CASE i.is_unique WHEN 1 THEN 'UNIQUE ' ELSE '' END
		--> CLUSTERED ?
		+CASE i.type WHEN 1 THEN 'CLUSTERED ' ELSE '' END
		--> INDEX [NOME_INDICE] ON [NOME_SCHEMA] ON [NOME_OBJETO]
		+'INDEX '+QUOTENAME(i.name)+' ON '+QUOTENAME(OBJECT_SCHEMA_NAME(i.object_id))+'.'+QUOTENAME(OBJECT_NAME(i.object_id))
		--> ([PrimColuna],...) INCLUDE([PrimColunaINC],...)
		+
		CONVERT(varchar(max),
			(SELECT --> Monta a lista de colunas, tanto key-columns, como INCLUDE. (Na ordem correta!)
				--> Este CASE irá controlar os comandos que serão colocados antes do nomes das colunas, isto é, um '(' ou um 'INCLUDE(' ou ','
				CASE  /**RRG27032012-01**/
					WHEN IC.key_ordinal	= 1 THEN '('
					WHEN ROW_NUMBER() OVER(PARTITION BY IC.is_included_column ORDER BY IC.column_id) = 1 
							AND IC.is_included_column = 1 THEN 'INCLUDE('
					ELSE ','
				END
				+
				QUOTENAME(C.name) + CASE WHEN IC.is_included_column = 0 AND ic.is_descending_key = 1  THEN ' DESC' ELSE '' END --> [ASC|DESC] 
				+
				CASE --> Este case irá controlar quando deve ser colocado o parênteses de fechamento do INCLUDE ou do inicial!!!!
					/**RRG27032012-01**/
					WHEN ROW_NUMBER() OVER(PARTITION BY IC.is_included_column ORDER BY IC.column_id DESC) = 1 
							AND IC.is_included_column = 1 THEN ') '
					WHEN ROW_NUMBER() OVER(ORDER BY IC.is_included_column ASC,IC.key_ordinal DESC)	= 1 THEN ') '
					ELSE ''
				END  AS 'text()'
			FROM
							sys.index_columns	IC
				INNER JOIN	sys.columns			C	ON	C.column_id = IC.column_id
													AND C.object_id	= IC.object_id
			WHERE
					IC.index_id		= I.index_id
				AND	IC.object_id	= I.object_id
			ORDER BY
				IC.is_included_column,IC.key_ordinal,IC.column_id
			FOR XML PATH('')
			) --> Fim da subquery que monta a lista de colunas.
		)
		+
		' WITH ('
		+'PAD_INDEX = '+CASE i.is_padded WHEN 1 THEN 'ON' ELSE 'OFF' END
		+',FILLFACTOR = '+CAST(CASE i.fill_factor WHEN 0 THEN 100 ELSE I.fill_factor END AS VARCHAR(3))
		+',IGNORE_DUP_KEY = '+CASE i.ignore_dup_key WHEN 1 THEN 'ON' ELSE 'OFF' END
		+',STATISTICS_NORECOMPUTE = '+CASE s.no_recompute WHEN 1 THEN 'ON' ELSE 'OFF' END 
		+',ALLOW_ROW_LOCKS = '+CASE i.allow_row_locks WHEN 1 THEN 'ON' ELSE 'OFF' END 
		+',ALLOW_PAGE_LOCKS = '+CASE i.allow_page_locks WHEN 1 THEN 'ON' ELSE 'OFF' END+ 
		+',SORT_IN_TEMPDB = '+@SORT_IN_TEMPDB+
		+',DROP_EXISTING = '+@DROP_EXISTING
		+',ONLINE = '+@ONLINE
		+',MAXDOP = '+@MAXDOP
		+')'
		+' ON '+ISNULL(CASE WHEN @PosicaoParenteses > 0 THEN @DataSpace ELSE QUOTENAME(@DataSpace) END,DataSpace.nome)
FROM
				sys.indexes			I 
	INNER JOIN	sys.stats			S	on	S.object_id		= I.object_id
										and S.stats_id		= I.index_id
	CROSS APPLY (
					SELECT
						 ps.name+'('+c.name+')' as nome
					FROM
									sys.index_columns		IC
						INNER JOIN	sys.columns				C	ON	C.column_id			= IC.column_id
																AND C.object_id			= IC.object_id
						INNER JOIN	sys.partition_schemes	PS	ON PS.data_space_id		= I.data_space_id
															AND	IC.partition_ordinal	= 1
					WHERE
							IC.object_id			= I.object_id
						AND	I.index_id				= I.index_id	
						
					UNION ALL
					
					SELECT	
						'['+f.name+']'
					FROM
						sys.filegroups f
					WHERE
						f.data_space_id = i.data_space_id
				) DataSpace
WHERE
		I.OBJECT_ID = OBJECT_ID(@NomeObjeto)
	and	I.name		= @NomeIndice

RETURN @SQLFinal

END
GO
	
