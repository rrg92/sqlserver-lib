-- JevTest
Use AiDecisionsTest
GO

-- criar as keys
/*
create master key encryption by password = 'Test@123'

CREATE DATABASE SCOPED CREDENTIAL
    [https://api.typesafe.ai]
WITH
    IDENTITY = 'HTTPEndpointHeaders',
    SECRET = '{"Authorization":"Bearer apikey"}';
*/

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

	
-- invocar a api do jev!


	declare @Decision nvarchar(max) = (
		select
			state = 'resolver error no linux'
			,model = 'jev-latest'
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


	declare @JevResp nvarchar(max)

	exec sp_invoke_external_rest_endpoint
		@url = 'https://api.typesafe.ai/v1/systemone'
		,@payload = @Decision
		,@response = @JevResp output
		,@credential = [https://api.typesafe.ai]

	declare @ResponseStatus int = JSON_VALUE(@JevResp,'$.response.status.http.code')

	select convert(json,@JevResp)

	if @ResponseStatus != 200
	begin
		select Error = convert(json,@JevResp)
		return;
	end	
		
	drop table if exists #DecisionResult;
	select
		PostId = p.[key]
		,Prob = p.value 
	into
		#DecisionResult
	from
		openjson(@JevResp,'$.result.answers.rerank.probabilities') p
	order by 
		p.value desc


-- comparar!




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