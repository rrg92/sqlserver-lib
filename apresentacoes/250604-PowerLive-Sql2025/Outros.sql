use master
go

-- https://learn.microsoft.com/en-us/sql/sql-server/what-s-new-in-sql-server-2025?view=sql-server-ver17
-- É um SQL 25 mesmo?
	SELECT @@VERSION,SERVERPROPERTY('ProductVersion'),SERVERPROPERTY('Edition'),@@SERVERNAME


--	Banco de Testes!
	if DB_ID('PowerLive') IS NOT NULL
		EXEC('ALTER DATABASE PowerLive SET READ_ONLY WITH ROLLBACK IMMEDIATE; drop database PowerLive')
	GO

	CREATE DATABASE PowerLive;
	GO
 
USE PowerLive
GO


--- Fuzzy
	
	select 
		EDIT_DISTANCE('cesar','cezar')
		,EDIT_DISTANCE('quadra 20, casa 40','qud 20, casa 50')
		,JARO_WINKLER_SIMILARITY('cesar','cezar')
		,JARO_WINKLER_SIMILARITY('césar','rodrigo')
		,JARO_WINKLER_SIMILARITY('rua cesar lopes, 40','rua cezar lpes 40')
		,JARO_WINKLER_SIMILARITY('rua cesar lopes, 40','avenida cesar macedo, 101')

		--existente
		,soundex('cesar'),soundex('cézar')


-- Concatenar string ANSI
	select 
		'Oi, meu nome é:' || 'Rodrigo!'

-- dateadd bigint 

	select 
		dateadd(ms,3956844427576,'19000101')
		,CURRENT_DATE

