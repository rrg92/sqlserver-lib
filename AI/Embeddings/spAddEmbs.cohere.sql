/*#info 
	# Autor
		Rodrigo Ribeiro Gomes 

	# descricao
		Implementa a sp_AddEmbeddings para a Cohere
		Vide sp_AddEmbeddings.sql
*/

CREATE OR ALTER PROC sp_GetEmbeddings_cohere (
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


	if @model is null
		set @model = 'embed-v4.0'

	-- exige autenticacao!
	if @credential is null
		set @credential = 'https://api.cohere.com'
	
	-- https://docs.cohere.com/v2/reference/embed
	declare
		@SupportedModels TABLE(model varchar(200), Dimensions json)



	insert into @SupportedModels
	values
		('embed-english-v3.0', '[1024]')
		,('embed-multilingual-v3.0','[1024]')
		,('embed-english-light-v3.0','[384]')
		,('embed-multilingual-light-v3.0','[384]')
		,('embed-english-v2.0','[4096]')
		,('embed-english-light-v2.0','[1024]')
		,('embed-multilingual-v2.0','[768]')
		,('embed-v4.0','[256,512,1024,1536]')


	if not exists(select * From @SupportedModels where model = @model and JSON_CONTAINS(Dimensions,@dimensions,'$[*]') = 1)
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
			,input_type = 'search_document'
			,embedding_types = JSON_QUERY('["float"]')
			,output_dimension = @dimensions
		for json path,without_array_wrapper
	)	

	if @Debug = 1
		raiserror('[cohere] reqoptions: %s',0,1,@reqoptions) with nowait;

	exec @retval = sp_invoke_external_rest_endpoint
		@url = 'https://api.cohere.com/v2/embed',
		@method = 'POST',
		@credential = @credential,
		@payload = @reqoptions,
		@response = @response output

	if @Debug = 1
		raiserror('[cohere] result: %s',0,1, @response ) with nowait;

	declare
		@HttpStatus int = JSON_VALUE(@response,'$.response.status.http.code')
		,@HttpResult nvarchar(max) = JSON_QUERY(@response,'$.result')

	set @result = (
		select 
			 ok = iif(@HttpStatus = 200,1,0)
			,error = iif(@HttpStatus = 200,null,JSON_QUERY(@HttpResult))
			,embeddings = JSON_QUERY(@response,'$.result.embeddings.float')
		for json path, without_array_wrapper
	)

GO
