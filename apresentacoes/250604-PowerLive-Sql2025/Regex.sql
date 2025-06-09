use master
go

-- É um SQL 25 mesmo?
	SELECT @@VERSION,SERVERPROPERTY('ProductVersion'),SERVERPROPERTY('Edition') ,@@servername


--	Banco de Testes!
	if DB_ID('PowerLive') IS NOT NULL
		EXEC('ALTER DATABASE PowerLive SET READ_ONLY WITH ROLLBACK IMMEDIATE; drop database PowerLive')
	GO

	CREATE DATABASE PowerLive;
	GO
 
USE PowerLive
GO


--- Recriando tabela posts...

	-- Vamos popular com alguns artigos do blog TheSqlTimes
	declare @PostsJson nvarchar(max)
	exec sp_invoke_external_rest_endpoint 'https://thesqltimes.com/blog/wp-json/wp/v2/posts?_fields=id,title,excerpt,tags,link,content&per_page=100'
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
			,conteudo nvarchar(max) '$.content.rendered'
			,link varchar(500)
		)

	select * from posts


-- Até o sql 2022

	select * from posts	where titulo like '[0-9]%'

-- NEw func: Regex_Count
	-- https://learn.microsoft.com/en-us/sql/relational-databases/regular-expressions/overview?view=sql-server-ver17
	-- https://aurelio.net/regex/

	select
		* 
		,REGEXP_COUNT(titulo,'^[0-9]')
	from 
		posts
	where
		REGEXP_COUNT(titulo,'^[0-9]') > 0

-- Nova sintaxe: db 170

	select  * from posts where REGEXP_LIKE(titulo,'^[0-9]')

	use master 
	select  * from posts where REGEXP_LIKE(titulo,'^[0-9]')

	use PowerLive	
	select *,REGEXP_LIKE(titulo,'^[0-9]') from posts 


-- Diferenciais do like: substituicao

	-- como remover as tags HTML?
	select 
		resumo
		,REGEXP_REPLACE(resumo,'<.*?>','')
	from
		posts

-- Diferenciais do like: encontrar as ocorrencias 

	SELECT 
		*
	FROM
		REGEXP_MATCHES('ABCBDEFBXB12B.X123B9B10','B\d+')
	OPTION(RECOMPILE)


	SELECT 
		p.titulo
		,m.*
	FROM
		posts p 
		cross apply
		REGEXP_MATCHES(p.resumo,'"https?:.*?"') m
	OPTION(RECOMPILE)