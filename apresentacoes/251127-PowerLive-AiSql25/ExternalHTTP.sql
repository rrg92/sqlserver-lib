USE master 
GO
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

		
	-- request autenticado OpenAPI!

		create master key encryption by password = 'LuizLindo@2025'

		-- https://platform.openai.com/
		-- obter key: 
		create database scoped credential [https://api.openai.com]
		with Identity = 'HTTPEndpointHeaders', SECRET = '{"Authorization":"Bearer token"}'

		--> lista os modelos existentes!
			drop table if exists ModelosGpt;
			declare @resultado nvarchar(max)
			exec sp_invoke_external_rest_endpoint 
				@url = 'https://api.openai.com/v1/models'
				,@response = @resultado OUTPUT
				,@method = 'GET'
				,@credential = 'https://api.openai.com'
				 
			select * into ModelosGpt from openjson(@resultado,'$.result.data') with (
				id varchar(100)
			)	
			select @resultado;
			select * from ModelosGpt;

		--> gerar um texto!
			
			--> escolher modelo
			select * from ModelosGpt where id like '%gpt-4%'

			declare @resultado nvarchar(max)
			declare @opcoes nvarchar(max) = (
				select 
					model					= 'gpt-4.1-mini'
					,max_completion_tokens	= 100
					,n = 2
					,messages				 = (
												select 
													[role] = 'user', [content] = N'Olá, estou falando com voce a partir do SQL Server!'
												for json path
											)
				for json path,without_array_wrapper
			)
			select JsonOpcoes = @opcoes;
			exec sp_invoke_external_rest_endpoint 
				@url = 'https://api.openai.com/v1/chat/completions'
				,@payload = @opcoes
				,@response = @resultado OUTPUT
				-- ,@method = 'POST' -- padrao
				,@credential = 'https://api.openai.com'
				 
			drop table if exists #response;
			select resultado = @resultado into #response

			select
				*
			from
				#response r
				cross apply
				openjson(r.resultado,'$.result')

			select
				*
			from
				#response r
				cross apply
				openjson(r.resultado,'$.result.choices') with (
					mensagem nvarchar(max) '$.message.content'
					,finish_reason varchar(100) '$.finish_reason'
				)


	--> usaro resultado de um select como contexto!
			declare @resultado nvarchar(max)
			declare @opcoes nvarchar(max) = (
				select 
					model					= 'gpt-4.1-mini'
					,max_completion_tokens	= 500
					--,n = 2
					,messages				 = (
												select * from (
													select 
														[role] = 'user', content = name
													from
														sys.databases

													union all 

													select 
														[role] = 'user', [content] = N'Me explique resumidamente o que é cada um desses bancos de dados anteriores!'
												) msg
												for json path
											)
				for json path,without_array_wrapper
			)
			select JsonOpcoes = @opcoes;
			exec sp_invoke_external_rest_endpoint 
				@url = 'https://api.openai.com/v1/chat/completions'
				,@payload = @opcoes
				,@response = @resultado OUTPUT
				-- ,@method = 'POST' -- padrao
				,@credential = 'https://api.openai.com'

			drop table if exists #response;
			select resultado = @resultado into #response

			select
				*
			from
				#response r
				cross apply
				openjson(r.resultado,'$.result.choices') with (
					mensagem nvarchar(max) '$.message.content'
					,finish_reason varchar(100) '$.finish_reason'
				)