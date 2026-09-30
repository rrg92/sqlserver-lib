/*#info 

	# Autor 
		Rodrigo Ribeiro gomes

	# descricao 
		O objetivo desse script é testar a efetividade do modelos de decisao (Jev, Ollaya, Decions openai)
		no processo de RAG.

		Quando o sql 2025 foi lançado, ele veio com embeddings, para, basicamente, permitri que você busque por semantica.
		Mas, como eu já mostrei em diversas apresentacoes e blogs, os embeddings sozinhos não fazem magica e podem errar.
		Uma das técnicas mais usadas são os "rerankers", que permitem reclassificar os dados.
		Até entao, existiam apenas alguns modelos que conseguiam fazer isso...
		Com o Jev e essesmodelos baseados em decisao, talvez possamos adicionar o reranking usando eles.
*/

use master
go


--	Banco de Testes!
	if DB_ID('AiDecisionsTest') IS NOT NULL
		EXEC('ALTER DATABASE AiDecisionsTest SET READ_ONLY WITH ROLLBACK IMMEDIATE; drop database PowerLive')
	GO

	CREATE DATABASE AiDecisionsTest;
	GO
 
USE AiDecisionsTest
GO

-- Vamos popular as tabelas com os posts do meu blog!

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

-- Vamos usar o ollama para criar o modelo!
-- systemctl start ollama (wsl)
-- Usar o caddy para expor via https (enquanto nao permitem um Tf para permitir http em ambiente de teste, seria tao mais fácil isso Ms...)
-- caddy reverse-proxy --from localhost:11443 --to :11434
-- testar ollama:
-- https://localhost:11443
-- https://thesqltimes.com/blog/2025/11/27/configurando-o-sql-2025-com-ollama-no-mesmo-pc-localhost/

-- ollama pull embeddinggemma:latest
-- se tudo ok com o ollama, partiu criar:

	if exists(select * From sys.external_models where name = 'Ollama')
		drop external model Ollama;

	
	create external model Ollama
	with (
		  LOCATION = 'https://localhost:11443/api/embed'
		  ,API_FORMAT = 'ollama'
		  ,MODEL_TYPE = EMBEDDINGS
		  ,MODEL = 'embeddinggemma' -- usando 
	)


	-- NOVA FUNÇÃO: AI_GENERATE_EMBEDDINGS
	-- https://learn.microsoft.com/en-us/sql/t-sql/functions/ai-generate-embeddings-transact-sql?view=sql-server-ver17
	select 
		AI_GENERATE_EMBEDDINGS('teste' use model Ollama) 

	-- Vamos atualizar!
	ALTER TABLE posts ADD embeddings vector(768)

	-- dica: em producao, nao fazer tudo de uma vez em 1 transacao só, obviamente!
	update posts
	set embeddings = AI_GENERATE_EMBEDDINGS(resumo use model Ollama)


-- vamos pegar os top 30 relaciondos a erro no linux!

	declare @Busca vector(768) = AI_GENERATE_EMBEDDINGS('resolver error no linux' use model Ollama)
	
	drop table if exists #r1;

	select top 30
		*
		,CosDistance = VECTOR_DISTANCE('cosine',@Busca,embeddings)
	into
		#r1
	from
		 posts
	order by
		CosDistance 

	
	select * From #r1

-- Vamos usar o ollaya para invocar uma api igual ao jev
-- instale o ollay no seu linux ou windows: https://ollaya.dev/download
-- Usar o caddy para expor via https (de novo, ajuda noix ai Microsoft... uma tf simples ajudaria nisso)
-- caddy reverse-proxy --from localhost:11445 --to :11435 --disable-redirects
-- testar ollaya:
-- https://localhost:11445
-- Agora vamos um rereank com o jev!
-- Vamos mandar todas as opcoes encointradas e pedir um score

	declare @Decision nvarchar(max) = (
		select
			state = 'resolver error no linux'
			,model = 'laya:typed-decisions'
			,questions = convert(json,(
				select 
					rerank = convert(json,(
						select 
							type = 'choice'
							,instrunctions = 'Best for: resolver error no linux'
							,criteria = convert(json,(
								select 
									JSON_OBJECTAGG(id : titulo+resumo)
								from
									#r1	
							))
						for json path,without_array_Wrapper
					))
				for json path,without_array_Wrapper
			))
		for json path,without_array_Wrapper
	)

	


	declare @OllayaResp nvarchar(max)

	exec sp_invoke_external_rest_endpoint
		@url = 'https://localhost:11445/v1/systemone'
		,@payload = @Decision
		,@response = @OllayaResp output

	declare @ResponseStatus int = JSON_VALUE(@OllayaResp,'$.response.status.http.code')

	select convert(json,@OllayaResp)

	if @ResponseStatus != 200
	begin
		select Error = convert(json,@OllayaResp)
		return;
	end	
		
	drop table if exists #DecisionResult;
	select
		PostId = p.[key]
		,Prob = p.value 
	into
		#DecisionResult
	from
		openjson(@OllayaResp,'$.result.answers.rerank.probabilities') p
	order by 
		p.value desc

-- comparar


	select
		dr.PostId
		,dr.Prob
		,JevRnk = row_number() over(order by dr.Prob desc)
		,CosRnk = r1.Rnk
		,CosineDistance = r1.CosDistance
		,r1.titulo
		,r1.resumo
	from
		#DecisionResult dr 
		join (
			select 
				*
				,Rnk = row_number() over(order by Cosdistance)
			From 
				#r1
		) r1 
			on r1.id = dr.PostId
	order by
		Prob desc