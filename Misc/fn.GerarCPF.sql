/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Gera um determinado número de CPFs.
		Depende da view criada pelo script vw.GerarCPF.sql

*/

USE master
GO


IF OBJECT_ID('dbo.fnGerarCpf','IF') IS NULL
	EXEC('CREATE FUNCTION dbo.fnGerarCpf() RETURNS TABLE AS RETURN (select 1 as StubVersion)')
GO

ALTER FUNCTION dbo.fnGerarCpf(@MaxCpfs int)
RETURNS TABLE 
AS
RETURN (
	WITH nseed AS (
		SELECT 1 as N
		UNION ALL 
		SELECT N+1 FROM nseed WHERE N < 100
	), 
	N AS (
		SELECT top(@MaxCpfs) n1.* FROM nseed n1,nseed n2,nseed n3,nseed n4,nseed n5
	)
	select 
		C.cpf
	from
		N
		cross apply (
			select * from dbo.vwGeraCPF
		) C
)





		

			