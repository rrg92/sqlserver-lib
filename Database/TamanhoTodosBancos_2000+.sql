/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Uma versão do tamanho de todos os bancos que também funciona no SQL 2000
		O segredo é trocar por sysfiles.

*/


IF OBJECT_ID('tempdb..#TamanhoBancos') IS NOT NULL
	DROP TABLE #TamanhoBancos;

CREATE TABLE
	#TamanhoBancos( Banco sysname, TamanhoTotalPag int, TamanhoUsadoPag int );
	
EXEC sp_MSforeachdb '
	USE [?];


	INSERT INTO #TamanhoBancos
	SELECT
		 DB_NAME()
		,SUM(size) 
		,SUM(FILEPROPERTY(name,''SpaceUsed''))
	FROM
		sysfiles
'

SELECT 
	 @@SERVERNAME as ServerName
	,banco
	,ISNULL(SERVERPROPERTY('ComputerNamePhysicalNetBIOS'),SERVERPROPERTY('MachineName')) as ComputerName
	--,count(*) as DatabaseCount
	,TamanhoTotalPag/128 as Total
	,TamanhoUsadoPag/128 as Usado 
FROM
	#TamanhoBancos
ORDER BY
	Usado DESc
;

