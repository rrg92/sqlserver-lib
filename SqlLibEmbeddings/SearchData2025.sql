/*#info 

	# Autor 
		Rodrigo ribeiro Gomes 

	# Descricao 
		Exemplo de como procurar os embeddings na tabela de scripts, usando sql server 2025.
        Antes de executar, use o script ./IndexData2025.sql
        Ajuste o texto na variável @SearchText e rode a query.

        --

        Sample script showing how to search using embeddings in SQL Server 2025.
        Before running this, follow the instructions in ./IndexData2025.sql.
        Change the search text in the variable @SearchText and run the script.
*/
use SqlServerLib
go

declare @SearchText varchar(max) = 'cpu performance'

declare @search vector(1024) =  AI_GENERATE_EMBEDDINGS(@SearchText use model  HuggingFace)
       
select top 10
    *
from (
    select 
        RelPath
        ,Similaridade = 1-CosDistance
        ,ScriptContent = ChunkContent
        ,ContentLength = LEN(ChunkContent)
        ,CosDistance
    from
        (
            select 
                *
                ,CosDistance = vector_distance('cosine',embeddings,@search)
            from 
                Scripts 
        ) C
) v
order by
    CosDistance