/*

	-- Onde obter o sql 2025?
		https://aka.ms/getsqlserver2025
	
	-- doc do sql 2025
		https://learn.microsoft.com/en-us/sql/sql-server/what-s-new-in-sql-server-2025?view=sql-server-ver16

*/

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


-- Edição do SQL!
	
	select SERVERPROPERTY('Edition'),@@version


	-- Travado mesmo?
	create table OnlineIndextest(c int);
	create index ixtest on OnlineIndexTest(c) with(online = on)

   

-- REST API: sp_invoke_external_rest_endpoint 
-- doc:	https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql?view=fabric&viewFallbackFrom=sql-server-ver17&tabs=request-headers

	EXEC sp_configure 'external rest endpoint enabled',1
	RECONFIGURE


	-- Feriados Nacionais
	-- https://brasilapi.com.br/docs#tag/Feriados-Nacionais

	declare @resultado nvarchar(max)
	exec sp_invoke_external_rest_endpoint 
		@url = 'https://brasilapi.com.br/api/feriados/v1/2025'
		,@response = @resultado OUTPUT
		,@method = 'GET'

	SELECT @resultado
	SELECT * FROM OPENJSON(@resultado)
	SELECT * FROM OPENJSON(@resultado,'$.result') with (
		date date
		,name varchar(100)
		,type varchar(50)
	)

	-- como são os erros?
	declare @ret int
	exec @ret = sp_invoke_external_rest_endpoint 
		@url = 'https://brasilapi2.com.br/api/feriados/v1/2025'
	

		
	-- autenticação?
	-- https://httpbin.org/#/Auth

	--  sem autenticação!
		declare @resultado2 nvarchar(max)
		exec sp_invoke_external_rest_endpoint 
			@url = 'https://httpbin.org/bearer'
			,@response = @resultado2 OUTPUT
			,@method = 'GET'

		select * from openjson(@resultado2)
		

	-- adicionando autenticação!
		create master key encryption by password = 'LuizLindo@2025'

		
		create database scoped credential [https://httpbin.org]
		with Identity = 'HTTPEndpointHeaders', SECRET = '{"Authorization":"Bearer TokenTest"}'

		declare @resultado2 nvarchar(max)
		exec sp_invoke_external_rest_endpoint 
			@url = 'https://httpbin.org/bearer'
			,@response = @resultado2 OUTPUT
			,@method = 'GET'
			,@credential = 'https://httpbin.org'

		select * from openjson(@resultado2)	

	 -- adicionando autenticação, via query string!
		drop database scoped credential [https://httpbin.org] 
		create database scoped credential [https://httpbin.org]
		with Identity = 'HTTPEndpointQueryString', SECRET = '{"TestKey":"TestToken"}'

		declare @resultado2 nvarchar(max)
		exec sp_invoke_external_rest_endpoint 
			@url = 'https://httpbin.org/get'
			,@response = @resultado2 OUTPUT
			,@method = 'GET'
			,@credential = 'https://httpbin.org'

		select * from openjson(@resultado2)	


	-- SOMENTE HTTPS!
		exec sp_invoke_external_rest_endpoint 'http://httpbin.org/get'



-- Uma dica: Como colocar dados dinamicamente no request?
-- use for json!


declare @payload nvarchar(max) = (
	select 
	   teste = 123
	for json path 
)

declare @resultado2 nvarchar(max)
exec sp_invoke_external_rest_endpoint 
	@url = 'https://httpbin.org/post'
	,@response = @resultado2 OUTPUT
	,@payload = @payload

select * from openjson(@resultado2)	





