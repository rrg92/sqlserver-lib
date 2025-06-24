/*#info 

	# Autor 
		Rodrigo ribeiro Gomes 

	# Descricao 
		Esse script permite indexar este repositorio em um SQL Server 2025.
		Crie um banco chamado SqlServerLib (ou ajuste o Use abaixo com o banco desejado).
		E rode o script.
		Opcionalmente, crie uma database scoped credential do github para evitar problemas de limites (veja abaixo no codigo como fazer)
		Para pesquisa, use o script ./SearchData2025.sql (após executar este)
		---

		This script allows you to index this repo using only T-SQL and the new SQL Server 2025 AI features.
		Create a database called SqlServerLib (or change the USE statement in the script below).
		You can also create a scoped credential for the GitHub API to avoid rate limits (see later in the code).
		For search, use the script ./SearchData2025.sql (after running this)

*/
-- enable external endpoint
EXEC sp_configure 'external rest endpoint enabled',1
RECONFIGURE 
GO

-- Create if not exists 
-- create database SqlServerLib
USE SqlServerLib;


---- create the scripts table
if object_id('dbo.Scripts','U') IS NULL
	CREATE TABLE Scripts (
		 id int IDENTITY PRIMARY KEY WITH(DATA_COMPRESSION = PAGE)
		,RelPath varchar(1000) NOT NULL
		,ChunkNum int NOT NULL
		,ChunkContent nvarchar(max) NOT NULL
		,embeddings vector(1024)
	)

/*
Let's create an external model to generate our embeddings!
The CREATE EXTERNAL MODEL command only supports OpenAI, Ollama, or Azure.
However, our embedding function resides in the rrg92/sqlserver-lib-assistant Hugging Face Space.

To allow SQL Server to connect, we need a way to expose that space as one of the supported APIs.
The solution is simply a third space: https://huggingface.co/spaces/rrg92/sqlserver


	Simple diagram:

		SQL SERVER 2025 ----> rrg92/sqlserver space ---> rrg92/sqlserver-lib-assistant

		The rrg92/sqlserver space works as a wrapper that exposes an OpenAI-like API for any other Hugging Face space.
		You just need to expose a Gradio API with the endpoint /embed that receives text and returns the embeddings!

	For a large number of rows, this method can be inefficient, as it involves two requests.
	But for a small set of rows or for testing purposes, this is not a big problem.
*/
IF NOT EXISTS(SELECT * FROM sys.external_models WHERE name = 'HuggingFace')
	CREATE EXTERNAL MODEL HuggingFace
	WITH (
			LOCATION = 'https://rrg92-sqlserver.hf.space/v1/embeddings',
			API_FORMAT = 'OpenAI',
			MODEL_TYPE = EMBEDDINGS,
			MODEL = 'rrg92/sqlserver-lib-assistant'
	);  

-- test
-- select AI_GENERATE_EMBEDDINGS('fROM sQL SERVER' use model  HuggingFace)



-- Load data from github API
-- Remember api can 

declare 
	@result nvarchar(max)
	,@GitHubCredential sysname 

-- if not exists, will return null
select @GitHubCredential = name from sys.database_scoped_credentials cr where cr.name like 'https://api.github.com'
	
EXEC sp_invoke_external_rest_endpoint 'https://api.github.com/repos/rrg92/sqlserver-lib/git/trees/main?recursive=1'
	,@method = 'GET'
	,@response = @result OUTPUT
	,@credential = @GitHubCredential

	/* TIP: GitHub Api Tokens
		to avoid github rate limits, you can generate a token in your account and create a credential for SQL use.
		Generate here: https://github.com/settings/personal-access-tokens

		-- must create master key in current db
		create master key encryption by password = 'StrongPass@2025'
	
		-- create the credential, replace YOUR_GITHUB_TOKEN with generated token!
		CREATE DATABASE SCOPED CREDENTIAL  [https://api.github.com]
		with Identity = 'HTTPEndpointHeaders', SECRET = '{"Authorization":"Bearer YOUR_GITHUB_TOKEN"}'
	*/


IF JSON_VALUE(@result,'$.response.status.http.code') != 200
BEGIN
	SELECT 
		[=== github http errror====] = 'error'
		,*
	from	
		openjson(@result)
	RETURN;
END

drop table if exists #gitfiles;
select
	*
	,id = identity(int,1,1)
into
	#gitfiles
from
	openjson(@result,'$.result.tree') with (
		path varchar(1000)
		,sha varchar(200)
	)
where
	path like '%.sql'
	AND path not in (
		select RelPath from Scripts
	)

declare
	@id int = 0
	,@sha varchar(100)
	,@url varchar(1000)
	,@content varchar(max)
	,@embeddings vector(1024)
	,@path varchar(1000)

-- for each file get base64 content, and calculate embbeddings!
while 1 = 1
begin
	select top 1
		@id = id
		,@sha = sha
		,@url = 'https://api.github.com/repos/rrg92/sqlserver-lib/git/blobs/'+sha
		,@path = path
	from
		#gitfiles
	where
		id > @id
	order by 
		id 
	if @@ROWCOUNT = 0
		break 

	set @result = NULL
	exec sp_invoke_external_rest_endpoint @url
		,@method = 'GET'
		,@response = @result OUTPUT
		,@credential = @GitHubCredential

	-- AI_GENERATE_EMBEDDINGS('test' use  model HuggingFace)
	raiserror('Generating for %s',0,1,@path) with nowait;
	
	SELECT 
        -- here the conversion from bin to char can result some incorrect chars
		-- due to pt-bR special chars with accents (e.g, é = are/is)
        -- I should handle this with collation functions and adjust on repo
        -- but I will ignore this for avoid script being more complex!
        @content = CONVERT(varchar(max),BASE64_DECODE(CONVERT(varchar(max),value)))
    from
        OPENJSON(@result,'$.result')
    where
        [key] = 'content'


	if @content is not null
	begin
		set @embeddings = AI_GENERATE_EMBEDDINGS(@content use  model HuggingFace)
		-- if someerror happens, result will be null.
		-- To debug, use extended events!
	end


	insert into Scripts(RelPath,ChunkNum,ChunkContent,embeddings)
	select
		@path,1,@content,@embeddings
		
	
end

