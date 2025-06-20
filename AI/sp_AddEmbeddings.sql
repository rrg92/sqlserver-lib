/*#info 

	# Author 
		Rodrigo Ribeiro Gomes (https://iatalk.ing)

	# Detalhes 
		Eu criei esta procedure quando tiver acesso ao Private Preview do SQL Server 2025.
		A ideia aqui é ter um jeito genérico de gerar emebddings e agrupar o máximo possível em uma única requisição HTTP.
		Você deve usá-la em conjunto com as procs sp_GetEmbeddings_PROVIDER, onde provider é o nome que você passa em @provider.
		
		para cosultar:
			select Provider = replace(name,'sp_GetEmbeddings_','') from sys.procedures where name like 'sp_GetEmbeddings_%'
			
		estas procs estão definidas logo abaixo.
		Pode ser que precise criar a scoped credential, consulte a respectiva proc para mais detalhes.
		
	EXEMPLO:
	

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
	@TableName sysname
	,@TextCol sysname
	,@Provider varchar(100)
	,@Model varchar(100)		= null
	,@EmbeddingsCol sysname		= null
	,@IdCol sysname				= null
	,@options nvarchar(max) 	= null
)
AS

	DECLARE
		@ProviderProc SYSNAME = 'sp_GetEmbeddings_' + @provider 

	IF OBJECT_ID(@ProviderProc) IS NULL
	BEGIN
		RAISERROR('Provider %s not supported',16,1,@provider)
		RETURN;
	END

	declare
		@sql nvarchar(max)
		,@DatabaseName sysname
		,@ExecSql sysname

	SET @DatabaseName 	= ISNULL(PARSENAME(@TableName,3),DB_NAME())
	SET @ExecSql 		= @DatabaseName+'..sp_executesql'

	if left(@TableName,1) = '#'
		select @ExecSql = 'tempdb..sp_executesql'

	IF @IdCol IS NULL
	BEGIN


		EXEC @ExecSql N'

			SELECT TOP 1
				@ColumnName = ColName
			FROM
				(
					SELECT 
							I.index_id
						,IndexName	= I.name
						,ColName	= C.name
						,TypeName	= T.name
						,ColCount = COUNT(*) OVER(PARTITION BY I.index_id)
					FROM
						sys.indexes I
						INNER JOIN
						sys.index_columns IC
							ON IC.index_id = I.index_id
							AND IC.object_id = I.object_id
						INNER JOIN
						sys.columns C
							ON C.object_id = IC.object_id
							AND C.column_id = IC.column_id
						INNER JOIN
						sys.types T
							ON T.user_type_id = C.user_type_id
					WHERE
						I.object_id = OBJECT_ID(@TableName)
						AND
						I.is_unique = 1
				) I
			WHERE
				I.ColCount = 1
				AND
				(TypeName like ''%int'' OR TypeName like ''%time'')
			ORDER BY
				I.IndexName
		',N'@TableName sysname,@ColumnName sysname OUTPUT',@TableName,@IdCol OUTPUT

		if @IdCol is null
		begin
			raiserror('Cannot determine unique col',16,1);
			return;
		end
	END

	SET @sql = '
		SELECT TOP 1
			 @ColName = C.name
			,@ColSize = (C.max_length - 8)/4 -- 8 bytes overhead + 4 bytes per position
		FROM
			sys.columns C
			INNER JOIN
			sys.types T
				ON T.user_type_id = C.user_type_id
		WHERE
			C.object_id = OBJECT_ID(@TableName)
			AND
			T.name = ''vector''
			
			'+IIF(@EmbeddingsCol IS NULL,'','AND C.name = @ColName')+'
	'

	DECLARE
		@Dimensions int

	EXEC @ExecSql @sql,N'@TableName sysname,@ColName nvarchar(500) output,@ColSize int output',@TableName,@EmbeddingsCol OUTPUT,@Dimensions OUTPUT

	IF @EmbeddingsCol IS NULL
	BEGIN
		RAISERROR('Not found embedding col with vector type',16,1)
		RETURN;
	END



	set @sql = '
		SELECT 
			 @Texts = JSON_ARRAYAGG('+QUOTENAME(@TextCol)+' order by '+QUOTENAME(@IdCol)+')
		FROM
			'+@TableName+'
	'

	DECLARE
		@TextsJson nvarchar(max)


	EXEC @ExecSql @sql,N'@Texts nvarchar(max) OUTPUT',@TextsJson OUTPUT;

	declare @Result nvarchar(max)

	EXEC @ProviderProc 
		@texts = @TextsJson
		,@result = @Result OUTPUT
		,@model = @Model
		,@dimensions = @Dimensions
		,@options = @options

	drop table if exists #ResultsJson;
	select r.[key],r.value into #ResultsJson from OPENJSON(@Result) r

	SET @sql = '
	
		;with SrcTab as (
			SELECT 
				*
				,Rn = ROW_NUMBER() OVER(ORDER BY '+@IdCol+') - 1
			FROM
				'+@TableName+'
		)
		UPDATE
			T
		SET
			'+QUOTENAME(@EmbeddingsCol)+' = CONVERT(vector('+CONVERT(varchar,@Dimensions)+'),r.value)
		FROM
			SrcTab T
			JOIN 
			#ResultsJson r
				ON r.[key] = T.Rn
	'

	EXEC @ExecSql @sql,N'@Result nvarchar(max)',@Result;

GO



CREATE OR ALTER PROC sp_GetEmbeddings_openai (
	 @texts nvarchar(max)
	,@result nvarchar(max) OUTPUT
	,@model varchar(max) = NULL
	,@dimensions int = 768
	,@options nvarchar(max) = NULL
)
AS

	IF @model IS NULL
		SET @model = 'text-embedding-3-small'

	-- Agora é invocar!
	declare @response nvarchar(max)
	declare @retval int 
	declare @reqoptions nvarchar(max) = (
		select 
			input		= JSON_QUERY(@texts)
			,dimensions = @dimensions
			,model		= @model
		for json path,without_array_wrapper
	)

	
	exec @retval = sp_invoke_external_rest_endpoint
		@url = 'https://api.openai.com/v1/embeddings',
		@method = 'POST',
		@credential = 'https://api.openai.com',
		@payload = @reqoptions,
		@response = @response output

	select 
		@result = JSON_ARRAYAGG( JSON_QUERY(r.value,'$.embedding') ORDER BY r.[key])
	from 
		openjson(@response,'$.result.data') r

GO



CREATE OR ALTER PROC sp_GetEmbeddings_AzureOpenai (
	 @texts nvarchar(max)
	,@result nvarchar(max) OUTPUT
	,@model varchar(max) = NULL
	,@dimensions int = 768
	,@options nvarchar(max) = NULL
)
AS

	IF @model IS NULL
		SET @model = 'text-embedding-3-small'

	declare 
		@url nvarchar(max) = JSON_VALUE(@options,'$.url')
		,@credential nvarchar(1000) = JSON_VALUE(@options,'$.credential')
		
	IF @url IS NULL 
	BEGIN
		RAISERROR('Must set url in @options',16,1);
		RETURN;
	END
	
	IF @credential IS NULL 
	BEGIN
		set @credential = REGEXP_SUBSTR(CONVERT(nvarchar(4000),@url),'(^https?\://.+?)/',1,1,'c',1)
	END

	-- Agora é invocar!
	declare @response nvarchar(max)
	declare @retval int 
	declare @reqopts nvarchar(max) = (
		select 
			input		= JSON_QUERY(@texts)
			,dimensions = @dimensions
			,model		= @model
		for json path,without_array_wrapper
	)

	
	exec @retval = sp_invoke_external_rest_endpoint
		@url = @url,
		@method = 'POST',
		@credential = @credential,
		@payload = @reqopts,
		@response = @response output

	select 
		@result = --JSON_ARRAYAGG( JSON_QUERY(r.value,'$.embedding') ORDER BY r.[key] )
		'['+string_agg('"'+STRING_ESCAPE(r.value,'json')+'"',',') within group (order by r.[key])+']'
	from 
		openjson(@response,'$.result.data') r

GO



CREATE OR ALTER PROC sp_GetEmbeddings_cohere (
	 @texts nvarchar(max)
	,@result nvarchar(max) OUTPUT
	,@model varchar(max) = NULL
	,@dimensions int = 768
	,@options nvarchar(max) = NULL
)
AS

	IF @model IS NULL
		SET @model = 'embed-multilingual-v2.0'

	
	-- https://docs.cohere.com/v2/reference/embed
	declare
		@SupportedModels TABLE(model varchar(200), Dimensions int)

	insert into @SupportedModels
	values
		('embed-english-v3.0',1024)
		,('embed-multilingual-v3.0',1024)
		,('embed-english-light-v3.0',384)
		,('embed-multilingual-light-v3.0',384)
		,('embed-english-v2.0',4096)
		,('embed-english-light-v2.0',1024)
		,('embed-multilingual-v2.0',768)

	if not exists(select * From @SupportedModels where model = @model and Dimensions = @dimensions)
	begin
		RAISERROR('Model %s not supported with dimensions %d',16,1,@model,@dimensions);
		return;
	end

	-- Agora é invocar!
	declare @response nvarchar(max)
	declare @retval int 
	declare @reqoptions nvarchar(max) = (
		select 
			 texts = JSON_QUERY(@texts)
			,model = @model
			,input_type = 'classification'
			,embedding_types = JSON_QUERY('["float"]')
		for json path,without_array_wrapper
	)	

	exec @retval = sp_invoke_external_rest_endpoint
		@url = 'https://api.cohere.com/v2/embed',
		@method = 'POST',
		@credential = 'https://api.cohere.com',
		@payload = @reqoptions,
		@response = @response output

	select 
		@result = JSON_ARRAYAGG( JSON_QUERY(r.value ) ORDER BY r.[key])
	from 
		openjson(@response,'$.result.embeddings.float') r

GO

