use master
go

-- É um SQL 25 mesmo?
	SELECT @@VERSION,SERVERPROPERTY('ProductVersion'),SERVERPROPERTY('Edition') 


--	Banco de Testes!
	if DB_ID('PowerLive') IS NOT NULL
		EXEC('ALTER DATABASE PowerLive SET READ_ONLY WITH ROLLBACK IMMEDIATE; drop database PowerLive')
	GO

	CREATE DATABASE PowerLive;
	GO
 
USE PowerLive
GO


---  vector data type!
-- https://iatalk.ing/ia-sql-server-embeddings/
-- https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/ai-in-sql-server-2025-embeddings/

	DECLARE					-- Veiculo,Pessoa				
		 @carro vector(2)	= '[1,0]'
		,@onibus vector(2)	= '[1,0]'
		,@rainha vector(2)	= '[0,1]'

	SELECT 
		 [Carro Vs Onibus]	= VECTOR_DISTANCE('cosine',@carro,@onibus)
		,[Carro Vs Rainha]	= VECTOR_DISTANCE('cosine',@carro,@rainha)
		,[Onibus Vs Rainha] = VECTOR_DISTANCE('cosine',@onibus,@rainha)



	-- Em tabela, mesma coisa!
	DROP TABLE IF EXISTS ExemploVector	;
	CREATE TABLE ExemploVector(
		embeddings vector(5)
	)

	insert into ExemploVector values
		('[-1,-0.123,0,1.1,0.111]')
		,('[0,0,0,0,0]')
		,('[1,1,1,1,1]')

	

-- Como gera os embeddings?	APIs
	-- Invocando diretamente uma API...

	create master key encryption by password = 'LuizLindo@2025'


	-- Exemplos...
	-- OpenAI
	-- https://platform.openai.com/api-keys
		create database scoped credential [https://api.openai.com]
		with Identity = 'HTTPEndpointHeaders', SECRET = '{"Authorization":"Bearer "}'


		declare @result nvarchar(max)
		exec sp_invoke_external_rest_endpoint 
			@url = 'https://api.openai.com/v1/embeddings'
			,@credential = 'https://api.openai.com'
			,@payload = '{
				"input":"Um carro"
				,"model":"text-embedding-3-small"
				,"dimensions":1024
			}'
			,@response  = @result output 

		select * From openjson(@result)
		select convert(vector(1024),(JSON_QUERY(@result,'$.result.data[0].embedding')))

	-- ollama
	-- https://github.com/ollama/ollama/blob/main/docs/api.md#generate-embeddings
	-- http://localhost:11434
	-- https://localhost:11443

		declare @result nvarchar(max)
		exec sp_invoke_external_rest_endpoint 
			@url = 'https://localhost:11443/api/embed'
			,@payload = '{
				 "input":"Um carro"
				,"model":"nomic-embed-text"
			}'
			,@response  = @result output 

		select * From openjson(@result)
		select convert(vector(768),(JSON_QUERY(@result,'$.result.embeddings[0]')))



--- E, se tiver um monte de dados em uma tabela?

	-- Vamos popular com alguns artigos do blog TheSqlTimes
	declare @PostsJson nvarchar(max)
	exec sp_invoke_external_rest_endpoint 'https://thesqltimes.com/blog/wp-json/wp/v2/posts?_fields=id,title,excerpt,tags,link&per_page=100'
		,@response = @PostsJson output
		,@method = 'GET'

	drop table if exists posts;

	select 
		*
	into 
		posts
	from
		openjson(@PostsJson,'$.result') with (
			id int
			,titulo nvarchar(500)	'$.title.rendered'
			,resumo nvarchar(1000) '$.excerpt.rendered'
			,link varchar(500)
		)

	select * from posts

		
-- MAIS FÁCIL: Gerando embeddings usando external model!
	-- external model: https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-model-transact-sql?view=sql-server-ver17

	-- criando a "referencia" para o modelo!
	if exists(select * From sys.external_models where name = 'Ollama')
		drop external model Ollama;

	create external model Ollama
	with (
		  LOCATION = 'https://localhost:11443/api/embed'
		  ,API_FORMAT = 'ollama'
		  ,MODEL_TYPE = EMBEDDINGS
		  ,MODEL = 'nomic-embed-text'
	)


	-- NOVA FUNÇÃO: AI_GENERATE_EMBEDDINGS
	-- https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-embeddings-transact-sql?view=sql-server-ver17
	select 
		AI_GENERATE_EMBEDDINGS('Um carro' use model Ollama) 


	-- Agora fica fácil!
	select top 5
		*
		,AI_GENERATE_EMBEDDINGS(resumo use model Ollama)
	from
		posts 

	-- Vamos atualizar!
	ALTER TABLE posts ADD embeddings vector(768)

	-- dica: em producao, nao fazer tudo de uma vez em 1 transacao só, obviamente!
	update posts
	set embeddings = AI_GENERATE_EMBEDDINGS(resumo use model Ollama)

		-- curiosidade: gpu, wait_types


-- Realizando uma busca!

	declare @Busca vector(768) = AI_GENERATE_EMBEDDINGS('resolver error no linux' use model Ollama)
	-- resolver error no linux
	-- encontrar o texto dos objetos

	select top 10
		*
		,Diff = VECTOR_DISTANCE('cosine',@Busca,embeddings)
	from
		 posts
	order by
		Diff 


--- VECTOR INDEX!
	-- https://learn.microsoft.com/en-us/sql/relational-databases/vectors/vectors-sql-server?view=sql-server-linux-ver17
	-- https://learn.microsoft.com/en-us/sql/t-sql/statements/create-vector-index-transact-sql?view=sql-server-ver17
	-- https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-search-transact-sql?view=sql-server-ver17
	-- veja o plano...
	--- scan... , tabela de milhoes de linhas isso é um prob!
	-- tf: 

	-- DiskANN
   --- index: ajuda a achar mais rapido!
   DBCC TRACEON(466, 474, 13981, -1)
   create unique clustered index ixId on posts(id)
   create vector index ixVec1 on posts(embeddings) with (metric = 'cosine',type='DiskANN')


	-- nova função: VECTOR_SEARCH 
		declare @Busca vector(768) = AI_GENERATE_EMBEDDINGS('posts relacionados a backup' use model Ollama)

		SELECT 
			*
		FROM
			VECTOR_SEARCH (
				 table	= posts
				,column = embeddings 
				,similar_to = @Busca 
				,metric = 'cosine'
				,top_n = 10
			)

