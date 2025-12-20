/*#info 
	# Autor
		Rodrigo Ribeiro Gomes 

	# descricao
		Implementa a sp_AddEmbeddings para o Azure OpenAI
		Vide sp_AddEmbeddings.sql
*/


CREATE OR ALTER PROC sp_GetEmbeddings_AzureOpenai (
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


	set @result = (
		select 
			 embeddings = JSON_QUERY((
					select  
						JSON_ARRAYAGG( JSON_QUERY(r.value,'$.embedding')  ORDER BY r.[key] )
					from 
						openjson(@response,'$.result.data') r
				 ))
			,ok = convert(bit,1)
		for json path, without_array_wrapper
	)

GO



