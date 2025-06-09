use master
go

-- É um SQL 25 mesmo? (.\a25)
	SELECT @@VERSION,SERVERPROPERTY('ProductVersion'),SERVERPROPERTY('Edition'),@@SERVERNAME 


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
	exec sp_invoke_external_rest_endpoint 'https://thesqltimes.com/blog/wp-json/wp/v2/posts?_fields=id,link,title,excerpt,date,slug&per_page=100'
		,@response = @PostsJson output
		,@method = 'GET'

	drop table if exists posts;

	select 
		*
	into 
		posts
	from
		openjson(@PostsJson,'$.result')	  with (
			id int
			,js nvarchar(max) '$' as json
		)


		

-- Até o 22, json era só string...

	declare @json nvarchar(max) = '{"a":1}'
	
	select * from openjson(@json)
	select JSON_VALUE(@json,'$.a')

-- Novo tipo de dados: JSON =)

	declare @json json = '{"a":1}'

	select * from openjson(@json)
	select JSON_VALUE(@json,'$.a')

-- explorando o internals e na tabela!

	-- espaço!
	declare @json1 json = (select top 1 js from posts)
	declare @json2 nvarchar(max) = (select top 1 js from posts)

	select
		 [Json(type)]			=  @json1
		 ,[JsonLen(type)]		= datalength(@json1)
		 ,[Json(nvarchar)]		=  @json2
		 ,[JsonLen(nvarchar)]	= datalength(@json2)


	-- vendo o internals do JSON

	drop table if exists JsonData;
	create table JsonData(
		ColJson json, ColText nvarchar(max)
	)

	insert into JsonData
	values('{"a":1}','{"a":1}')

	-- select db_id('PowerLive')
	-- Use PowerLive
	select allocated_page_page_id,is_allocated	,page_type_desc
	from sys.dm_db_database_page_allocations( db_id('PowerLive'),object_id('JsonData'), null,null,'detailed')  

	dbcc traceon(3604)
	dbcc page('PowerLive',1,360,3)	


	-- mais dados
	truncate table JsonData;
	insert into JsonData
	select top 1 js,js from posts


	-- select db_id('PowerLive')
	-- Use PowerLive
	select allocated_page_page_id,is_allocated	,page_type_desc
	from sys.dm_db_database_page_allocations( db_id('PowerLive'),object_id('JsonData'), null,null,'detailed')  

	dbcc traceon(3604)
	dbcc page('PowerLive',1,360,3)	

	


-- Outra vantagem: -- JSON INDEX!
--- https://learn.microsoft.com/en-us/sql/t-sql/statements/create-json-index-transact-sql?view=sql-server-ver17


	-- add col json para comparar!
	select * from posts -- conferir

	alter table posts add js2 json;
	go
	update posts set js2 = js

	select 
		js
		,js2
		,EspacoJsonNvarchar = DATALENGTH(js)
		,EspacoJsonType = DATALENGTH(js2)
	from 
		posts

	select  
		TotalJsonNvarchar = sum(DATALENGTH(js))
		,TotalJsonType = sum(DATALENGTH(js2)) 
	from posts


-- testando sem indice!

	-- ver plano!
	select
		*
	from
		posts
	where
		JSON_VALUE(js,'$.slug') = '100-scripts-de-dba'


	alter table posts alter column id int not null 	
	go
	alter table posts add constraint pkPosts primary key(id)
	go
	create json index ixJson on posts(js2)
	go

	select
		*
	from
		posts
	where
		JSON_CONTAINS(js2,'100-scripts-de-dba','$.slug') = 1
	

	select
		*
	from
		posts with(forceseek)
	where
		JSON_VALUE(js2,'$.slug') = '100-scripts-de-dba'
	option(recompile)

-- curiosidade: stats
	-- dbcc show_statistics('posts','ixJson')
	select * from sys.stats where object_id = object_id('posts')

	-- https://techcommunity.microsoft.com/blog/sqlserver/announcing-the-public-preview-of-json-index-in-sql-server-2025/4415321	
	-- https://learn.microsoft.com/en-us/sql/t-sql/statements/create-json-index-transact-sql?view=sql-server-ver17#json_value-function

