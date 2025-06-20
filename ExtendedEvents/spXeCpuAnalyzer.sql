/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Uma proc simples que criei para analisar as métricas de CPU coletadas por XE. 
		A ideia é coletar os eventos usando o SSMS e exportar para uma tabela (usando o proprio recurso de export XE do ssms). 
		Então você usaria essa proc passando o nome da tabela que definiu na hora de exportar.
		Usei em algumas situações para analisar problemas de cpu em ambientes pesados, com muitas queries pequenas.
		Me ajudou a tirar insights, como qual a base mais usada, tempos e query (pelo qury_hash). 
		Quando temos muitas queries rodando muito rápido, essa proc pode ajudar muito analisar os dados do XE de forma agregada, e aparecer o banco ou query vilã.
		
		
		
*/
create procedure spXeCpuAnalyzer(@tab sysname,@col_query_hash sysname = 'query_hash')
AS

-- open xe in ssms
-- use export to table
-- run this proc and pass table name here.


declare @sql nvarchar(max)

set @sql = '

-- Total...
SELECT 
	MinEvent = MIN(timestamp)
	,MxEvent = MAX(timestamp) 
	,QtdEvts = COUNT(*)
	,DATEDIFF(MS,MIN(timestamp),MAX(timestamp))
	,TotalCpu = SUM(cpu_time/1000)
	,TotalDuration = SUM(duration/1000)
FROM 
	'+@tab+'
where
	'+@col_query_hash+' != 0

-- per db...
SELECT 
	 database_name
	,Qtd = COUNT(*)
	,TotalCpu = SUM(cpu_time/1000)
	,TotalDurs = SUM(duration/1000)
FROM 
	'+@tab+'
where
	'+@col_query_hash+' != 0
group by 
	database_name
order by
	TotalCpu desc


-- per query...
select top 50 q.*,qt.* from (
SELECT 
	 '+@col_query_hash+'
	,Qtd = COUNT(*)
	,TotalCpu = SUM(cpu_time/1000)
	,TotalDurs = SUM(duration/1000)
	,MinCpu = MIN(cpu_time/1000)
	,AvgCpu = AVG(cpu_time/1000)
	,MaxCpu = MAX(cpu_time/1000)
FROM 
	'+@tab+'
where
	'+@col_query_hash+' != 0 
group by 
	'+@col_query_hash+'
) q 
cross apply (
select top 1 s.statement,s.sql_text,s.database_name from '+@tab+' s where s.'+@col_query_hash+' = q.'+@col_query_hash+'
) qt
order by
	TotalCpu desc

'

exec sp_executesql @sql;