/*#info 

	# Author 
		Rodrigo Ribeiro Gomes (https://iatalk.ing)

	# Detalhes 
		Eu criei esta procedure desde o Private Preview do SQL Server 2025, quando conheci os novos comandos de AI com AI_GENERATE_EMBEDDINGS.
		O maior problema hoje com AI_GENERATE_EMBEDDINGS é que ela faz apenas 1 por vez, mas a maioria dos providers permitem enviar vários textos.
		Isso ajuda a montar menos reqs http e tcp, isto é , menos overhead, e ajuda na performance final.

		A ideia aqui é ter um jeito genérico de gerar emebddings e agrupar o máximo possível em uma única requisição HTTP.
		Você deve usá-la em conjunto com as procs sp_GetEmbeddings_PROVIDER, onde provider é o nome que você passa em @provider.
		Outra vantagem é que você pode usar com qualquer provider, basta implementar uma procedure chamada sp_GetEmbeddings_Provider e traduzir.  
		Por padrão, envio usando a mesma sintaxe da OpenAI.
		Eu criei vários exemplos, olhe nos arquivos em, spAddEmbs.*.sql
		
		Para listar os providers existentes:
			select Provider = replace(name,'sp_GetEmbeddings_','') from sys.procedures where name like 'sp_GetEmbeddings_%'
			
		estas procs estão definidas logo abaixo.
		Pode ser que precise criar a scoped credential, consulte a respectiva proc para mais detalhes.

	ARQUITETURA
		A ideia básica é: Você usa sp_AddEmbeddings e escolhe qual provider quer usar.
		Informa o texto ou a tabela de origem, e a sp_Addembedings cuida do resto.
		Os providrs disponíveis podem ser criados por você ou por mim, ou por qualquer um da comunidade.

		A sp_AddEmbeddings define um padrão que as procs precisam implementar e gerencia a execucao e intepretacao dos resultados.
	EXEMPLOS:
	

		DROP TABLE IF EXISTS #messages

		select top 10 
			 id = IDENTITY(int,1,1)
			,text
			,embeddings = convert(vector(768),null)
		into 
			#messages
		From sys.messages where language_id = 1033

		create unique index ix1 on #messages(id);

		select * from #messages
		exec sp_AddEmbeddings '#messages','text','cohere'
		select * from #messages
*/


CREATE OR ALTER PROCEDURE sp_AddEmbeddings(
	 @TableName sysname						-- Nome da tabela que você quer atualizar
	,@TextCol sysname						-- Nome da coluna de texto que será usada para gerar os embeddings
	,@Provider varchar(100)					-- Nome do provider
	,@model nvarchar(1000)		= null		-- Nome do modelo a ser usado
	,@EmbeddingsCol sysname		= null		-- Nome da coluna com embeddings. Se null, padrão procura a coluna com o tipo vector
	,@IdCol sysname				= null		-- Nome da coluna de id. A proc exige uma coluna unica (unique ou primayr key). Se null, tenta usar alguma que tenha um indice unico.
	,@options nvarchar(max) 	= null		-- json com as opcoes adicionais que serao passadas a proc do provider
	,@credential nvarchar(max)	= null		-- nome da credential a ser usada
	,@url nvarchar(max)			= null		-- base url da api. para modelos que aceitam.
	,@BatchSize int				= 50		-- quantidade de linhas para serem processadas de uma só vez!
	,@IsExternal bit			= 0			--> trata o parametro @Model como o nome de um external model (Create external model) do banco atual
	,@debug bit = 0							--> habilia infos de debug
)
AS

	DECLARE
		@ProviderProc SYSNAME = 'sp_GetEmbeddings_' + @provider 
		,@MasterProc sysname = 'master..'
		,@DebugJson nvarchar(max)
		,@CurrentDb sysname = db_name()
		,@SqlDb nvarchar(100)

	set @MasterProc = 'master..'+@ProviderProc
	set @SqlDb = @CurrentDb+'..sp_executesql'

	IF OBJECT_ID(@ProviderProc) IS NULL AND OBJECT_ID(@MasterProc) IS NULL
	BEGIN
		RAISERROR('Provider %s not supported',16,1,@provider)
		RETURN;
	END


	exec sp_set_session_context 'AddEmbeddings-Debug', @debug; 


	declare
		@sql nvarchar(max)
		,@DatabaseName sysname
		,@ExecSql sysname

	SET @DatabaseName 	= ISNULL(PARSENAME(@TableName,3),DB_NAME())
	SET @ExecSql 		= @DatabaseName+'..sp_executesql'

	if left(@TableName,1) = '#'
		select @ExecSql = 'tempdb..sp_executesql'

	declare
		@IdColType varchar(100)

	-- Obter informacoes da coluna de id!
	set @sql =  N'
		SELECT TOP 1
			 @ColumnName = ColName
			,@ColType = TypeName
		FROM
			(
				SELECT 
					 IndexName	= I.name
					,ColName	= C.name
					,TypeName	= T.name
					,ColCount	= COUNT(*) OVER(PARTITION BY I.index_id)
				FROM
					sys.columns C
					INNER JOIN
					sys.types T
						ON T.user_type_id = C.user_type_id
					LEFT JOIN (
						sys.index_columns IC
						INNER JOIN
						sys.indexes I
							ON I.object_id = IC.object_id
							AND I.index_id = IC.index_id
					)
						ON C.object_id = IC.object_id
						AND C.column_id = IC.column_id
				WHERE
					C.object_id = OBJECT_ID(@TableName)
					AND
					'+IIF(@IdCol IS NULL
						,'I.is_unique = 1' -- se nao tem @IdCol, entao filtra somente os indices unicos.
						,'C.name = @ColumnName'
					)+'
					AND
					(
						T.name like ''%int''
						OR
						T.name like ''%time''
						OR
						T.name in (''uniqueidentifier'')
					)
			) I
		WHERE
			1 = 1
			'+IIF(@IdCol IS NULL,'AND I.ColCount = 1','')+' -- Se estpa no modo auto, entao somente colunas com 1 coluna
	'
	
	IF @debug = 1
		RAISERROR('Get col info sql: %s',0,1,@sql) with nowait;

	EXEC @ExecSql @sql,N'@TableName sysname,@ColumnName sysname OUTPUT, @ColType nvarchar(100) OUTPUT',@TableName,@IdCol OUTPUT,@IdColType OUTPUT

	if @debug = 1
		RAISERROR('Id col: %s, type: %s',0,1,@IdCol,@IdColType) with nowait;

	if @IdColType is null
	begin
		raiserror('Cannot determine unique col',16,1);
		return;
	end



	SET @sql = '
		SELECT TOP 1
			 @ColName = C.name
			,@Dimensions = C.vector_dimensions --- (C.max_length - 8)/4 -- 8 bytes overhead + 4 bytes per position
		FROM
			sys.columns C
			INNER JOIN
			sys.types T
				ON T.user_type_id = C.user_type_id
		WHERE
			C.object_id = OBJECT_ID(@TableName)
			AND
			T.name = ''vector''
			
			'+IIF(@EmbeddingsCol IS NULL,'',' AND C.name = @ColName')+'
	'

	DECLARE
		@Dimensions int

	IF @debug = 1
		RAISERROR('Get vector col: %s',0,1,@sql) with nowait;

	EXEC @ExecSql @sql,N'@TableName sysname,@ColName nvarchar(500) output,@Dimensions int output',@TableName,@EmbeddingsCol OUTPUT,@Dimensions OUTPUT

	IF @EmbeddingsCol IS NULL
	BEGIN
		RAISERROR('Not found embedding col with vector type',16,1)
		RETURN;
	END

	declare
		@ExternalModelName sysname

	IF @IsExternal = 1
	BEGIN
		set @ExternalModelName = @Model

		SELECT
			 @model			= em.model
			,@url			= ISNULL(@url,em.location)
			,@credential	= ISNULL(@credential,c.name)
		FROM
			sys.external_models em
			left join
			sys.database_scoped_credentials c
				on c.credential_id = em.credential_id
		WHERE
			em.name = @model

		IF @@ROWCOUNT = 0
		BEGIN
			RAISERROR('External model %s not found',16,0,@model)
			RETURN;
		END
		
	END


	--> executando a query dinamica acima e obtendo os textos!
	DECLARE 
		@TextsJson nvarchar(max)
		,@LastId sql_variant
		,@Ids nvarchar(max)
		,@TotalRows bigint
		,@Result nvarchar(max)
		,@UpdateSql nvarchar(max)
		,@ProviderParams json

	--> Sql get Next1
	set @sql = '
		declare @LastIdType '+@IdColType+' = convert('+@IdColType+', @LastId)

		IF @LastIdType IS NULL
			SET @LastIdType = CONVERT('+@IdColType+',0);

		select
			 @Texts = JSON_ARRAYAGG(TextCol ORDER BY IdCol)
			,@Ids = JSON_ARRAYAGG(IdCol ORDER BY IdCol)
			,@LastId = CONVERT(sql_variant,MAX(IdCol))
			,@TotalRows = count(*)
		from (
			SELECT TOP(@top)
				*
			FROM 
			(
				select
						TextCol = '+QUOTENAME(@TextCol)+'
					,IdCol = '+QUOTENAME(@IdCol)+'
				from
					'+@TableName+'
			) T
			WHERE
				T.IdCol > @LastIdType
			ORDER BY
				T.IdCol
		) t
	'

	-- explico a logica desse update mais abaixo.
	SET @UpdateSql = '
	
			;with SrcTab as (
				SELECT 
					IdCol =  '+QUOTENAME(@IdCol)+'
					,EmbCol = '+QUOTENAME(@EmbeddingsCol)+'
				FROM
					'+@TableName+'
			)
			UPDATE
				T
			SET
				EmbCol = r.Embs
			
			
			'+IIF(@Debug = 1,'OUTPUT ''DebugUpdateOutput'' as Dgb,deleted.*,inserted.*','')+'
			
			
			FROM
				SrcTab T
				JOIN 
				#ResultsJson r
					ON CONVERT('+@IdColType+',r.SrcId) = T.IdCol
		'

	IF @debug = 1
	BEGIN
		RAISERROR('Sql next cols: %s',0,1,@sql) with nowait;
		RAISERROR('Sql update embeddings: %s',0,1,@UpdateSql) with nowait;
	END

	--> Agora que obtemos os embeddins, vamos atualizar de volta na tabela que o usuario passou!
	drop table if exists #ResultsJson;
	CREATE TABLE #ResultsJson(
		 SrcId sql_variant
		,Embs nvarchar(max)
	)

	-- Neste ponto ja temos a coluna de id e a coluna de vector que vamos atualizar
	WHILE 1 = 1
	BEGIN
		SELECT @TotalRows = 0,@Ids = null, @TextsJson = null
		EXEC @ExecSql @sql
					,N'@Texts nvarchar(max) OUTPUT, @top int, @LastId sql_variant OUTPUT, @TotalRows bigint OUTPUT, @Ids nvarchar(max) OUTPUT'
					,@TextsJson OUTPUT, @BatchSize, @LastId OUTPUT,@TotalRows OUTPUT, @Ids OUTPUT

		IF @debug = 1 RAISERROR('Next ids: %s, textos: %s',0,1,@Ids, @TextsJson) with nowait;

		IF @TotalRows = 0 OR @TotalRows IS NULL
			BREAK;

		

		--> Neste ponto temos os textos em json!
		if @debug = 1 raiserror('Calling proc: %s',0,1, @ProviderProc) with nowait;

		/*
			Agora vamos passar o controle pra proc do provider e deixar ele fazer a magica!
		
			Para que isso funciona, a proc do provider deve implementar os seguintes parametros:
				- result  = O resultado. Deve ser um objeto com as seguintes keys:
							embeddings: Array com os embeddings mesma ordem em que os textos foram informados.
							ok: true se deu sucesso, 0 se deu algum erro.
							error: Detalhes do erro
				- params = Um json com algumas parametros adicionais (nao implementado via parametros da proc pra manter mais compativel com mudancas)
					Keys aceitaveis:
					- texts: Um json contendo o array de textos
					- model = O nome do modelo a ser usado 
					- dimensions =  a quantidade de dimensoes que queremos
					- credential = credential a ser usada. Se null, o provider pode determinar uma por padrao!
					- options = um json com opcoes adicionais, que cada provider pode definir e usar como quiser (a proc do provider deve documentar)
		*/

		set @ProviderParams = (
			SELECT
				 model		= @model 
				,options	= JSON_QUERY(@options)
				,dimensions	= @Dimensions
				,credential	= @credential
				,texts		= JSON_QUERY(@TextsJson)
				,url		= @url

				,IsExternal = @IsExternal
				,ExternalName = @ExternalModelName
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		)
		
		set @result = NULL
		EXEC @ProviderProc 
			 @result = @Result OUTPUT
			,@params = @ProviderParams

		if @debug = 1
			raiserror('Proc result: %s',0,1,@result) with nowait;

		if convert(bit,json_value(@Result,'$.ok')) != 1
		begin
			raiserror('Provider proc %s nao confirmou sucesso! Result: %s',16,1, @ProviderProc, @result);
			return;
		end


		truncate table #ResultsJson;

		/*
		Aqui vamos inserir de volta o resultado.
		Cada elemento do array corresponde a um id, e em ordem crescente.
		Portando, o embeddings da posicao 0, é referente ao id da posicao 0 no array e ids.
		Por exemplo, suponha que uma tabela tenha os ids 1,20,21,22,30,31,35,50 e o @BatchSize é 3, logo vamos processar por vez.
		Na primeita iteração, iremos processar os ids 1,20,21. 
		Será gerado um array de ids [1,20,21] e um array de textos ["texto id 1","texto id 20","texto do id 21"].
		Quando a api retorna, termos o resultado em  [EmbeddingsId1,EmbeddingsId20,Embeddings21].
		Logo, para saber em qual linha eu devo atualizar o embeddings, basta que eu use o index do array:
		

		 0             1              2					--> index do array (coluna r.key na tablea abaixo.)
		
		[1            ,20            ,21              ]
		["texto id 1" ,"texto id 20" ,"texto do id 21"]
		[EmbeddingsId1,EmbeddingsId20,Embeddings21    ]
		
		Assim, apenas usando o index do array retornado, eu consigo achar o id de volta e atualizar na tabela.
		Se a tabela tem um índice unico (que é o esperado de se usar), esse update é extremamente rápido.
		*/
		INSERT INTO #ResultsJson(SrcId,Embs)
		SELECT 
			 CONVERT(sql_variant,JSON_VALUE(@Ids,'$['+r.[key]+']'))
			,r.value 
		FROM
			OPENJSON(@Result,'$.embeddings') r

		if @debug = 1
			select * from #ResultsJson;

		EXEC @ExecSql @UpdateSql;
	END

GO

EXEC sp_MS_marksystemobject sp_AddEmbeddings
GO
