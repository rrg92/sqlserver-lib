/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Um das primeiras funcoes que criei para gerar o create index.
		Tem scripts melhores. Mas deixarei aqui para referência e histórico.
		
		
*/

IF object_id('dbo.fnGeraCreateIndice') IS NOT NULL
	DROP FUNCTION dbo.fnGeraCreateIndice
GO

CREATE FUNCTION dbo.fnGeraCreateIndice
(
	 @objetoID			varchar(400)
	,@NomeIndice		varchar(400)
	,@SORT_IN_TEMPDB	varchar(3) = 'OFF'
	,@DROP_EXISTING		varchar(3) = 'OFF'
	,@ONLINE			varchar(3) = 'OFF'
	,@MAXDOP			varchar(3) = '0'
)
RETURNS VARCHAR(MAX)
AS
BEGIN
--> Configuráveis pelo usuário
--DECLARE
--	 @objetoID			varchar(400)
--	,@NomeIndice		varchar(400)
--	,@SORT_IN_TEMPDB	varchar(3)
--	,@DROP_EXISTING		varchar(3)
--	,@ONLINE			varchar(3)
--	,@MAXDOP			varchar(3)
--SET @objetoID			= 'alunos'
--SET @NomeIndice		= 'alunos_pk'
--SET @SORT_IN_TEMPDB = 'OFF'
--SET @DROP_EXISTING	= 'OFF'
--SET @ONLINE			= 'OFF'
--SET @MAXDOP			= '0'

DECLARE
	 @InicioCREATE	varchar(max)
	,@ColsChaves	varchar(max)
	,@ColsInclude	varchar(max)
	,@OpcoesWITH	varchar(max)
	,@Armazenamento	varchar(max)
	,@SQLFinal		varchar(max)
	
SET @ColsChaves  = ''
SET @ColsInclude = ''
	
SELECT
	@InicioCREATE = ----> CREATE até o nome do objeto	
		'CREATE '+CASE i.is_unique 
					WHEN 1 THEN 'UNIQUE ' 
					ELSE '' 
				 END
				+CASE i.type 
					WHEN 1 THEN 'CLUSTERED '
					ELSE ''
				 END
		+'INDEX '+i.name
		+' ON '+OBJECT_NAME(i.object_id)
	,@OpcoesWITH = ----> Opções WITH de criação do índice.
		 'WITH ('
		+'PAD_INDEX = '
			+CASE i.is_padded 
				WHEN 1 THEN 'ON' 
				ELSE 'OFF' 
			END
		+',FILLFACTOR = '
			+CAST(i.fill_factor AS VARCHAR(3))
		+',IGNORE_DUP_KEY = '
			+CASE i.ignore_dup_key 
				WHEN 1 THEN 'ON' 
				ELSE 'OFF' 
			END
		+',STATISTICS_NORECOMPUTE = '
			+CASE s.no_recompute 
				WHEN 1 THEN 'ON' 
				ELSE 'OFF' 
			END 
		+',ALLOW_ROW_LOCKS = '
			+CASE i.allow_row_locks 
				WHEN 1 THEN 'ON' 
				ELSE 'OFF' 
			END 
		+',ALLOW_PAGE_LOCKS = '
			+CASE i.allow_page_locks 
				WHEN 1 THEN 'ON' 
				ELSE 'OFF' 
			END+ 
		+',SORT_IN_TEMPDB = '+@SORT_IN_TEMPDB+
		+',DROP_EXISTING = '+@DROP_EXISTING
		+',ONLINE = '+@ONLINE
		+',MAXDOP = '+@MAXDOP
		+')'
		,
	 @ColsChaves = @ColsChaves + ---> Colunas Chaves do Índice
		CASE
			WHEN ic.is_included_column = 0 THEN

					CASE @ColsChaves
						WHEN '' THEN '('+c.name
						ELSE ','+c.name
					END
					+CASE ic.is_descending_key --> [ASC|DESC]
						WHEN 1 THEN ' DESC'
						ELSE ' ASC'
					 END
			ELSE
				''
		END
	 ,@ColsInclude = @ColsInclude + ----> Colunas Include do índice
		CASE
			WHEN ic.is_included_column = 1 THEN
				CASE @ColsInclude 
					WHEN '' THEN 'INCLUDE('+c.name
					ELSE ','+c.name
				END
			ELSE
				''
		END
	 ,@Armazenamento = 'ON '+espaco.nome
FROM
				sys.indexes			i 
	INNER JOIN	sys.index_columns	ic	on	ic.object_id	= i.object_id
										and	ic.index_id		= i.index_id
	INNER JOIN	sys.columns			c	on	c.column_id		= ic.column_id
										and c.object_id		= i.object_id
	INNER JOIN	sys.stats			s	on	s.object_id		= i.object_id
										and s.stats_id		= i.index_id
	CROSS APPLY	(
					SELECT	
						ps.name+'('+c.name+')' as nome
					FROM
						sys.partition_schemes ps
					WHERE
							ps.data_space_id = i.data_space_id
						and ic.partition_ordinal <> 0
						
					UNION
					
					SELECT	
						'['+f.name+']'
					FROM
						sys.filegroups f
					WHERE
						f.data_space_id = i.data_space_id
				) espaco
WHERE
		i.object_id = object_id(@objetoID)
	and	i.name		= @NomeIndice
ORDER BY
	 i.object_id
	,i.index_id
	,ic.key_ordinal

--> Fechano o parênteses, onde for necessário
SET @ColsChaves		= @ColsChaves + ')';
IF @ColsInclude <> ''
	SET @ColsInclude = @ColsInclude + ')';

SET @SQLFinal = @InicioCreate +' '+ @ColsChaves +' '+ @ColsInclude +' '+ @OpcoesWITH +' '+ @Armazenamento

RETURN @SQLFinal

END
GO

EXEC sp_MS_marksystemobject 'dbo.fnGeraCreateIndice'
GO

	
