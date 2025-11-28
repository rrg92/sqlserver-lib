/*
  pequeno exemplo de como a ai_generate_chunks funciona!
*/

use PowerLive 
go

select
	*
from
	(select 'abcdef' as texto) t
	cross apply
	ai_generate_chunks(source=texto, chunk_type = fixed, chunk_size = 2, overlap = 50, enable_chunk_set_id =1) c





select
	p.id,p.titulo,p.resumo
	,c.*
from
	posts p
	cross apply
	ai_generate_chunks(source=resumo, chunk_type = fixed, chunk_size = 10, overlap = 50, enable_chunk_set_id =1) c
where
	id = 3