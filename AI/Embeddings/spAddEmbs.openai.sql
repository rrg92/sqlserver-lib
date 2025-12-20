/*#info 
	# Autor
		Rodrigo Ribeiro Gomes 

	# descricao
		Implementa a sp_AddEmbeddings para a OpenAi
		Vide sp_AddEmbeddings.sql
*/

CREATE OR ALTER PROC sp_GetEmbeddings_openai (
	 @result nvarchar(max) OUTPUT
	,@params json 
)
AS

	DECLARE
		@texts nvarchar(max)		= CONVERT(nvarchar(max),JSON_QUERY(@params,'$.texts'))
		,@model varchar(max)		= CONVERT(nvarchar(max),JSON_VALUE(@params,'$.model'))
		,@dimensions int			= CONVERT(int,JSON_VALUE(@params,'$.dimensions'))
		,@options nvarchar(max)		= CONVERT(nvarchar(max),JSON_QUERY(@params,'$.options'))
		,@credential nvarchar(max)	= CONVERT(nvarchar(max),JSON_VALUE(@params,'$.credential'))
		,@IsExternal bit			= CONVERT(bit,JSON_VALUE(@params,'$.IsExternal'))
		,@url nvarchar(max)			= CONVERT(nvarchar(max),JSON_VALUE(@params,'$.url')) -- url alternativa!


	declare @Debug bit = convert(int,SESSION_CONTEXT(N'AddEmbeddings-Debug'))

	IF @IsExternal = 1
	BEGIN
		SELECT
			@model = name
			,@url  = ISNULL(@url,location)
		FROM
			sys.external_models em
		WHERE
			name = @model
	END

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

	-- exige autenticacao!
	if @credential is null
		set @credential = 'https://api.openai.com'

	if @url is null
		set @url = 'https://api.openai.com/v1/embeddings'
	
	if @Debug = 1
		raiserror('[openai] reqoptions: %s',0,1,@reqoptions) with nowait;

	exec @retval = sp_invoke_external_rest_endpoint
		@url = @url,
		@method = 'POST',
		@credential = @credential,
		@payload = @reqoptions,
		@response = @response output

	if @Debug = 1
		raiserror('[openai] result: %s',0,1, @response ) with nowait;

	declare
		@HttpStatus int = JSON_VALUE(@response,'$.response.status.http.code')
		,@HttpResult nvarchar(max) = JSON_QUERY(@response,'$.result')

	set @result = (
		select 
			 ok = iif(@HttpStatus = 200,1,0)
			,error = iif(@HttpStatus = 200,null,JSON_QUERY(@HttpResult))
			,RawResponse = JSON_QUERY(iif(@Debug = 1,@response,null))
			,embeddings = JSON_QUERY((
					select  
						JSON_ARRAYAGG( JSON_QUERY(r.value,'$.embedding')  ORDER BY r.[key] )
					from 
						openjson(@response,'$.result.data') r
				 ))
		for json path, without_array_wrapper
	)

GO

