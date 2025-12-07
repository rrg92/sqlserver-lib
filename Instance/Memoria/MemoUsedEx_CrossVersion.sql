/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Informacoes do consumo de memória dos componentes do sql, que funciona antes e depoos do 2012 (que mudou algumas colunas)

*/


IF OBJECT_ID('tempdb..#MemoInfo') IS NOT NULL
	DROP TABLE #MemoInfo;
CREATE TABLE #MemoInfo(component varchar(400), memoMB decimal(30,2) );

DECLARE
	@tsql_Cmd nvarchar(4000)
	,@MemoSource nvarchar(500)	
;

IF EXISTS(SELECT * FROM sys.all_columns WHERE object_id = OBJECT_ID('sys.dm_os_memory_clerks') AND name = 'pages_kb')
	SET @MemoSource = 'MC.pages_KB + MC.virtual_memory_committed_kb'
ELSE
	SET @MemoSource = 'MC.single_pages_kb + MC.multi_pages_kb + MC.virtual_memory_committed_kb + MC.awe_allocated_kb'



SET @tsql_Cmd = N'
	INSERT INTO
		#MemoInfo
	SELECT
		MC.type
		,('+@MemoSource+')*1.00/1024 as MemoMB
	FROM
		sys.dm_os_memory_clerks MC
'


EXEC sp_executesql @tsql_Cmd;

SELECT
	*
FROM
(
	SELECT
		 MI.*
		,CASE
			WHEN MI.component like '%BUFFERPOOL%' THEN MI.component	
			WHEN MI.component like '%CP'  THEN 'PLAN_CACHE' 	
			WHEN MI.component like '%PHDR'  THEN 'PLAN_CACHE'	
			WHEN MI.component like '%OBJECTSTORE%' THEN 'PLAN_CACHE'	
			ELSE 'OUTROS' 
		END as ComponentGroup
	FROM
		#MemoInfo MI
) MI