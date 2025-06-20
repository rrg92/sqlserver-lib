/*#info 

	# Author 
		Rodrigo Ribeiro Gomes (https://iatalk.ing)

	# Detalhes 
		Exemplo de como gerar embeddings usando sp_invoke_external_rest_endpoint e OpenAI
		Funciona apenas no sql 2025+
*/

-- create database ia!
use ia
GO

-- create scoped credential!
	-- o nome da credential precisa ter pelo menos o domonio bas da url usada!
	-- exemplo: esse aqui serve para api.openai.com/*
	if not exists(select * from sys.database_scoped_credentials where name = 'https://api.openai.com')
		create database scoped credential
			[https://api.openai.com]
		with identity = 'HTTPEndpointHeaders'
			,SECRET = '{"Authorization":"Bearer SUA_API_KEY"}'


	-- Agora é invocar!
	declare @response nvarchar(max)
	declare @retval int 
	declare @options nvarchar(max) = (
		select 
			input = (select JSON_ARRAYAGG('oi') )
			,dimensions = 768
			,model = 'text-embedding-3-small'
		for json path,without_array_wrapper
	)	
	


	exec @retval = sp_invoke_external_rest_endpoint e OpenAI
		@url = 'https://api.openai.com/v1/embeddings',
		@method = 'POST',
		@credential = [https://api.openai.com],
		@payload = @options,
		@response = @response output

	select 
		r.[key]
		,embedding = CONVERT(vector(768),JSON_QUERY(r.value,'$.embedding'))
	from 
		openjson(@response,'$.result.data') r



