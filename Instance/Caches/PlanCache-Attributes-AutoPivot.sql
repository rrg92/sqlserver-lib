/*#info

	# autor 
		Rodrigo 

	# descricao 
		Retorna os atributos de um plano como uma tabela, para facilitar a visualiazação.
		Normalmebte, você precisa usar um pivot, ou algo do tipo. Esse script facilita isso.


		Esse script da função fnDelimitar, disponível em Misc/fnDelimitar.sql

		ATENÇÃO: ESSE SCRIPT PODE VARRER O SEU PLAN CACHE E CAUSAR UM ALTO CONSUMO DE CPU. Use com cuidado!

*/

USE master
GO

DECLARE
	@Attribs nvarchar(max) 
	
SET @Attribs = 'set_options,inuse_exec_context';


IF OBJECT_ID('tempdb..#PlanAtrib') IS NOT NULL
	DROP TABLE #PlanAtrib;
CREATE TABLE
	#PlanAtrib( c bit );
	
IF OBJECT_ID('tempdb..#PlanDados') IS NOT NULL
	DROP TABLE #PlanDados;
	
	
IF OBJECT_ID('tempdb..#PlanCacheAttrib') IS NOT NULL
	DROP TABLE #PlanCacheAttrib;
CREATE TABLE
	#PlanCacheAttrib( nome nvarchar(max) );

DECLARE
	 @SQLCmd nvarchar(max)
	,@ColunasAttribs nvarchar(max)
	,@ColunasAttribsMolde nvarchar(max)
	,@FiltroAttribs nvarchar(max)
	,@AttribsDelimStr nvarchar(max)
	,@AttribsSQLCmdMolde nvarchar(max)
	,@NomeTempTable	nvarchar(max)
	,@ColsMetaTipoAttribs nvarchar(max)
	,@AlterTableStr nvarchar(max)
	,@AlterTableDropCStr nvarchar(max)
;

-- inserindo as opções em uma tabela que deverá ser consultada.
SET @SQLCmd = model.dbo.fnDelimitar( @Attribs
									,N'INSERT INTO #PlanCacheAttrib(nome) VALUES('+CHAR(0x27)
									,NCHAR(0x27)+N');'
									,N','
									,0 --> Não manter o separador
									);	
EXECUTE(@SQLCmd);								

-- Montando a parte das colunas com os atributos
SET @ColunasAttribs = N'';
SET @ColunasAttribsMolde = N',MAX( CASE pa.attribute WHEN '+QUOTENAME('$[ATTRIB_NOME]',NCHAR(0x27))+N' THEN pa.value END) as [$[ATTRIB_NOME]] ';

-- Criando a versao delimitada com aspas simples de cada atributo
SET @AttribsDelimStr = model.dbo.fnDelimitar(@Attribs
									,DEFAULT	--> Aspas simples
									,DEFAULT	--> Aspas simples
									,DEFAULT	--> vírgula
									,DEFAULT	--> Manter o separador na substiuição
									);
SET @FiltroAttribs = N'pa.attribute IN '+QUOTENAME(@AttribsDelimStr,N'(');
SELECT
	@ColunasAttribs = @ColunasAttribs + REPLACE(@ColunasAttribsMolde,N'$[ATTRIB_NOME]',pca.nome) + NCHAR(13)+NCHAR(10)
FROM
	#PlanCacheAttrib pca
	
-- Criando o string contendo o IN com nomes de tipos de dados que tem parênteses
SET @ColsMetaTipoAttribs = N'nvarchar,varchar,varbinary,binary,char,nchar'
SET @ColsMetaTipoAttribs = model.dbo.fnDelimitar(@ColsMetaTipoAttribs
									,DEFAULT	--> Aspas simples
									,DEFAULT	--> Aspas simples
									,DEFAULT	--> vírgula
									,DEFAULT	--> Manter o separador na substiuição
									);

-- Tabela temporária gerada internamente na query dinamica.
SET @NomeTempTable = N'#PlanAttribDinamic';

-- String contendo o começo do alter table das colunas.
SET @AlterTableStr = QUOTENAME(N'ALTER TABLE #PlanAtrib ADD',CHAR(0x27))

-- String contendo o começo do alter para remover a coluna.
SET @AlterTableDropCStr = N'ALTER TABLE #PlanAtrib DROP COLUMN c;'

SET @AttribsSQLCmdMolde = N'
	DECLARE
		 @SQLCmdD nvarchar(max)
		 ,@SQLAlterTable nvarchar(max)
	;
	
	SET @SQLCmdD = N'''';

	SELECT
		 cp.plan_handle
		,cp.objtype
		,cp.cacheobjtype
		,cp.size_in_bytes
		,cp.usecounts
		,cp.refcounts
		$[ATTRIBS_COLUNAS]
	INTO
		'+@NomeTempTable+'
	FROM 
		sys.dm_exec_cached_plans cp
			CROSS APPLY
		sys.dm_exec_plan_attributes(cp.plan_handle) pa
	WHERE
		$[ATTRIBS_FILTROS]
	GROUP BY
		 cp.plan_handle
		,cp.objtype
		,cp.cacheobjtype
		,cp.size_in_bytes
		,cp.usecounts
		,cp.refcounts

	/*
		Esta parte da query irá montar um ALTER TABLE ... ADD para adicionar as colunas
		geradas do insert acima, na tabela temporária criada fora do script.
		Assim a tabela de fora terá os mesmos campos que a tabela criada dentro deste batch.
	*/
	SELECT
		@SQLCmdD = @SQLCmdD +
		$[ATTRIBS_ALTERTABLE_STR_COL]
			+
		CHAR(0x20)
			+
		 c.name 
			+ 
		CHAR(0x20) 
			+ 
		tp.name
			+
		CHAR(0x20) 
			+
		CASE 
			WHEN tp.name IN ($[ATTRIBS_COLSMETA_TIPOS]) THEN QUOTENAME(
														CONVERT(NVARCHAR(MAX)
															,CASE c.max_length
																WHEN -1 THEN '+QUOTENAME('max',NCHAR(0x27))+'
																ELSE c.max_length
															 END
															)
														,'+QUOTENAME('(',NCHAR(0x27))+'
													)
												
														
			ELSE N''''
		END
			+
		'+QUOTENAME(N';',NCHAR(0x27))+' --> Ponto-e-vírgula
	FROM
		tempdb.sys.tables t
		JOIN
		tempdb.sys.columns c
			ON c.object_id = t.object_id
		JOIN
		tempdb.information_schema.columns isc
			ON	isc.table_name	= t.name
			AND isc.column_name	= c.name
		JOIN
		tempdb.sys.types tp
			ON tp.user_type_id = c.user_type_id
	WHERE 
		t.object_id = OBJECT_ID('+QUOTENAME(N'tempdb..'+@NomeTempTable,CHAR(0x27))+')
	ORDER BY
		isc.ordinal_position
	;
	
	EXEC(@SQLCmdD)
	
	---> Comando para fazer o alter table e dropar  a coluna "c".
	$[ATTRIBS_ALTERTABLE_STR_DROPCOL]
	
	INSERT INTO
		#PlanAtrib
	SELECT
		*
	FROM
		'+@NomeTempTable+'
';

-- Montando o comando para obter as informações de um plano específico.
SET @SQLCmd = REPLACE(@AttribsSQLCmdMolde,N'$[ATTRIBS_COLUNAS]',@ColunasAttribs)
SET @SQLCmd = REPLACE(@SQLCmd,N'$[ATTRIBS_FILTROS]',@FiltroAttribs)
SET @SQLCmd = REPLACE(@SQLCmd,N'$[ATTRIBS_COLSMETA_TIPOS]',@ColsMetaTipoAttribs)
SET @SQLCmd = REPLACE(@SQLCmd,N'$[ATTRIBS_ALTERTABLE_STR_COL]',@AlterTableStr)		
SET @SQLCmd = REPLACE(@SQLCmd,N'$[ATTRIBS_ALTERTABLE_STR_DROPCOL]',@AlterTableDropCStr)

EXECUTE(@SQLCmd)
		SELECT * FROM 	#PlanAtrib;	
