USE AiTools
GO

/*
	Esta proc foi criada para funcionar com o Power Omni.
	Saiba mais em https://poweromni.ai
*/

-- precisa habilitar o preview features, ja que vamos usar o VECTOR_SEARCH:
--    ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
-- spOmniArtigosRodrigo 'problema de cpu'

CREATE OR ALTER PROC spOmniArtigosRodrigo(@texto nvarchar(max), @top int = 10)
AS
/*omni
description: Busca os artigos mais relevantes para um assunto
params:
  texto: O texto da busca
  top: O maximo de artigos a serem retornados
*/


declare @Busca vector(768) = AI_GENERATE_EMBEDDINGS(@texto use model Ollama)

SELECT 
	titulo
	,resumo
	,link
FROM
	VECTOR_SEARCH (
		 table	= Powerlive..posts
		,column = embeddings 
		,similar_to = @Busca 
		,metric = 'cosine'
		,top_n = @top
	)