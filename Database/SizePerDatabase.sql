/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Query rápida para trazer o tamanho real de todos os bancos da instância.
		No final, traz o tamanho de cada banco e o total da instância.
		Tudo em MB

*/


IF OBJECT_ID('tempdb..#TamanhoBancos') IS NOT NULL
	DROP TABLE #TamanhoBancos;

CREATE TABLE
	#TamanhoBancos( Banco sysname, TamanhoTotalPag int, TamanhoUsadoPag int );
	
EXEC sp_MSforeachdb '
	USE [?];
	
	INSERT INTO #TamanhoBancos
	SELECT
	 db_name()
	 ,SUM(size) 
	 ,SUM(FILEPROPERTY(name,''SpaceUsed''))
	FROM
		sys.database_files
'

select 
	Banco
	,sum(TamanhoTotalPag)/128.0 as Total
	,sum(TamanhoUsadoPag)/128.0 as Usado 
from #TamanhoBancos

 GROUP BY
	Banco with rollup
	;

